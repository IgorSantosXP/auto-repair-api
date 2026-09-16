# Auto Repair API

Backend Rails 8.1 API-only para gerenciamento de uma oficina mecânica. Cobre ordens de serviço, cadastro de clientes/veículos, controle de estoque, fluxo de aprovação de orçamentos e notificação de clientes por e-mail.

## Fase 3 — Objetivos e solução

A aplicação foi para a nuvem, com segurança, escalabilidade e observabilidade:

- **API Gateway** — ponto único de entrada, com throttling e log de acesso; roteia a autenticação para uma Lambda e o restante para o cluster via VPC Link
- **Autenticação por CPF** — função serverless valida o CPF, confirma o cliente na base e emite um JWT de cliente, com público (`aud`) distinto do token de administrador
- **AWS** — EKS com HPA, RDS PostgreSQL gerenciado, ECR, Secrets Manager, tudo provisionado por Terraform
- **Quatro repositórios** — Lambda, infraestrutura Kubernetes, infraestrutura de banco e aplicação, cada um com CI/CD, `main` protegida e deploy automático por OIDC
- **Observabilidade** — Datadog com APM, métricas de negócio, logs estruturados em JSON e correlação de requisição ponta a ponta
- **Modelo de dados** — índices e constraints novos para consistência e performance, documentados com diagrama ER

## Desenho da arquitetura

O diagrama de componentes, com a visão de nuvem completa, está em
**[docs/architecture/component-diagram.md](docs/architecture/component-diagram.md)**.

```
Cliente → API Gateway ─┬─ POST /auth/cpf → Lambda → RDS
                       └─ ANY /api/*  → VPC Link → NLB → EKS (Rails + HPA) → RDS
                                                          └→ Datadog
```

- **Subnets públicas**: nós do EKS, com IP público para alcançar ECR e a API do cluster
- **Subnets privadas**: RDS, Lambda e o NLB interno, sem rota para a internet — não há NAT Gateway, o que economiza US$ 32/mês sem expor o banco
- **Dois ambientes** no mesmo cluster: namespaces `auto-repair-prod` (branch `main`) e `auto-repair-homolog` (branch `homolog`), com bancos separados na mesma instância RDS

## Stack

- **Ruby 3.4.3** / **Rails 8.1** — API-only, Solid Queue para jobs assíncronos (e-mails)
- **PostgreSQL 16** no **Amazon RDS** — índices únicos parciais, CHECK constraints, saldo de estoque via CASE-SUM
- **Node.js 22** — função Lambda de autenticação por CPF
- **JWT HS256** — dois públicos: administrador (TTL 24h) e cliente (TTL 1h)
- **RSpec** + **rswag** — testes geram a documentação OpenAPI automaticamente
- **AWS** — EKS, API Gateway, Lambda, RDS, ECR, Secrets Manager, provisionados com **Terraform**
- **Datadog** — APM, métricas customizadas via DogStatsD, logs JSON com `lograge`
- **GitHub Actions** — CI/CD nos quatro repositórios, autenticando por OIDC
- **Mailpit** — SMTP de demonstração com UI web

## Arquitetura da aplicação

O projeto segue **Clean Architecture** organizada em contextos delimitados (DDD) em `app/domains/`:

```
app/domains/
  identity/        # Usuário, JWT, caso de uso de autenticação
  registries/      # Cliente, Veículo, Serviço — value objects CPF/CNPJ/placa
  inventory/       # Peça, Movimentação de estoque, calculadora de saldo
  service_orders/  # Ciclo completo: máquina de estados, aprovação, orçamento, notificação
  reports/         # Queries de métricas
```

Mapeamento das camadas:

| Camada (Clean Architecture) | No projeto |
|---|---|
| **Entities** — regras de negócio corporativas | `app/domains/*/entities`, `value_objects` (CPF, CNPJ, placa, status) e `services` de domínio (máquina de estados, calculadora de orçamento) |
| **Use Cases** — regras de negócio da aplicação | `app/domains/*/use_cases` (criação/transição/aprovação de OS, autenticação, movimentação de estoque) e `queries` (listagens e métricas) |
| **Interface Adapters** — conversão de dados | `app/controllers` (REST/JSON, controllers finos que rendem um objeto `Result`), `app/mailers` + views de e-mail |
| **Frameworks & Drivers** — detalhes | Rails, PostgreSQL, SMTP, Solid Queue, JWT |

A regra de dependência aponta para dentro: controllers dependem de use cases, que dependem de entidades — nunca o contrário. A comunicação entre camadas usa o objeto `Result` (sucesso/falha + payload/erros), e efeitos colaterais de borda (como envio de e-mail) ficam atrás de serviços de domínio (`CustomerNotifier`), mantendo os use cases testáveis e o framework substituível. Casos de uso só existem onde há lógica de negócio real; CRUDs simples falam com o model diretamente.

## Documentação arquitetural

Índice completo em **[docs/](docs/)**: diagrama de componentes, diagramas de
sequência, 5 ADRs, 3 RFCs e o diagrama ER com a explicação dos relacionamentos.

| Documento | Assunto |
|---|---|
| [Componentes](docs/architecture/component-diagram.md) | Visão de nuvem e fluxo de deploy |
| [Sequência — autenticação por CPF](docs/architecture/sequence-auth-cpf.md) | Do CPF ao token, e do token à rota protegida |
| [Sequência — ordem de serviço](docs/architecture/sequence-service-order.md) | Abertura, orçamento, estoque, entrega |
| [ADRs](docs/adr/) | EKS, API Gateway, comunicação, HPA, quatro repositórios |
| [RFCs](docs/rfc/) | Escolha da nuvem, do banco e da estratégia de autenticação |
| [Modelo de dados](docs/database/er-diagram.md) | Diagrama ER e relacionamentos |

## Execução local (docker compose)

```bash
docker compose up --build
docker compose exec api bin/rails db:prepare db:seed
```

- API: `http://localhost:3000`
- Swagger UI: `http://localhost:3000/api-docs`
- Mailpit (e-mails enviados): `http://localhost:8025`

O seed cria o admin, o catálogo de serviços e peças, quatro clientes com CPF
válido e quatro ordens em status diferentes — os CPFs são impressos ao final,
para uso no endpoint de autenticação.

## Provisionamento da infraestrutura (Terraform)

A infraestrutura mora em três repositórios separados e a **ordem de aplicação é
obrigatória**, porque cada um lê as saídas do anterior via estado remoto:

```bash
# 1. rede, cluster, registro e borda   (~15-20 min)
git clone git@github.com:IgorSantosXP/auto-repair-infra-k8s.git
cd auto-repair-infra-k8s && make init && make up && make kubeconfig

# 2. banco gerenciado e segredos       (~10 min)
git clone git@github.com:IgorSantosXP/auto-repair-infra-database.git
cd auto-repair-infra-database && make init && make up

# 3. função de autenticação            (~2 min)
git clone git@github.com:IgorSantosXP/auto-repair-auth-lambda.git
cd auto-repair-auth-lambda && make init && make up
```

Pré-requisitos: Terraform >= 1.10, AWS CLI com perfil configurado, kubectl.
O bucket de estado remoto precisa existir antes do primeiro `init` — instruções
em [auto-repair-infra-k8s/bootstrap](https://github.com/IgorSantosXP/auto-repair-infra-k8s/tree/main/bootstrap).

> **Custo.** O control plane do EKS custa US$ 0,10/hora e não tem free tier.
> Rodando 24/7 o conjunto fica em torno de US$ 136/mês. Provisione para testar ou
> demonstrar e rode `make down` em cada repositório, na ordem inversa. O
> raciocínio está no [ADR 0001](docs/adr/0001-eks-como-orquestrador.md).

## Deploy em Kubernetes

Normalmente o deploy é feito pelo pipeline. Manualmente:

```bash
aws eks update-kubeconfig --region us-east-1 --name auto-repair-eks

REGISTRY=814623398856.dkr.ecr.us-east-1.amazonaws.com
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $REGISTRY
docker build -f Dockerfile.production -t $REGISTRY/auto-repair-api:latest .
docker push $REGISTRY/auto-repair-api:latest

kubectl apply -k k8s/overlays/prod
kubectl -n auto-repair-prod wait --for=condition=complete job/db-migrate --timeout=300s
kubectl -n auto-repair-prod rollout status deployment/api
kubectl -n auto-repair-prod exec deploy/api -- bin/rails db:seed
```

O Secret `api-secrets` é criado pelo pipeline a partir do Secrets Manager; para
deploy manual, crie-o antes com `DATABASE_URL`, `JWT_SECRET` e `SECRET_KEY_BASE`.

Os manifestos usam **kustomize**, em [k8s/](k8s/):

- `base/` — Deployment (2 réplicas, probes em `/up`, requests/limits), Service, HPA (2–5 réplicas, CPU 70% / memória 80%), Job de migração e Mailpit
- `overlays/prod/` — namespace `auto-repair-prod`, Service NodePort 30080 (alvo do NLB), imagem do ECR
- `overlays/homolog/` — namespace `auto-repair-homolog`, réplica única, Service interno

A URL pública é a do API Gateway:

```bash
aws apigatewayv2 get-apis --query "Items[?Name=='auto-repair-api'].ApiEndpoint | [0]" --output text
```

### Demonstração do autoscaling

```bash
# terminal 1 — acompanhe o HPA
kubectl -n auto-repair-prod get hpa,pods -w

# terminal 2 — gere carga contra o API Gateway
./script/load_test.sh "$GATEWAY_URL" 300 40
```

## CI/CD

Pipeline em [.github/workflows/ci.yml](.github/workflows/ci.yml):

| Gatilho | O que roda |
|---|---|
| Pull request | Brakeman, bundler-audit, RSpec completo, validação dos overlays kustomize |
| Push na `homolog` | Tudo acima + deploy no namespace `auto-repair-homolog` |
| Push na `main` | Tudo acima + deploy no namespace `auto-repair-prod` + smoke test no API Gateway |

O job de deploy assume a role `auto-repair-github-actions` por **OIDC** — não há
access key armazenada nos secrets do GitHub. Em seguida publica a imagem no ECR,
monta o Secret a partir do Secrets Manager, aplica os manifestos, espera o Job de
migração e o rollout, e valida o endpoint público.

A `main` é protegida nos quatro repositórios: commits diretos são recusados e o
merge exige pull request com os checks verdes.

## Documentação da API (collection)

- **Swagger UI interativo**: `http://localhost:3000/api-docs` (local) ou `http://localhost:8080/api-docs` (Kubernetes)
- **Spec OpenAPI**: [swagger/v1/swagger.yaml](swagger/v1/swagger.yaml) — importável no Postman/Insomnia

Para regenerar a partir dos testes: `bundle exec rake rswag:specs:swaggerize`

## Principais Endpoints

### Auth

| Método | Caminho | Descrição |
|--------|---------|-----------|
| POST | `/api/v1/auth/login` | Retorna token JWT |

### Admin (Bearer token obrigatório)

| Método | Caminho | Descrição |
|--------|---------|-----------|
| GET/POST | `/api/v1/customers` | Listar / criar clientes |
| GET/PATCH/DELETE | `/api/v1/customers/:id` | Exibir / atualizar / soft delete |
| GET/POST | `/api/v1/vehicles` | Listar / criar veículos |
| GET/POST | `/api/v1/services` | Listar / criar serviços |
| GET/POST | `/api/v1/parts` | Listar / criar peças |
| GET | `/api/v1/parts/:id/stock` | Saldo atual em estoque |
| POST | `/api/v1/parts/:part_id/stock_movements` | Registrar entrada/saída/ajuste |
| GET/POST | `/api/v1/service_orders` | Listar / criar ordens de serviço |
| GET/PATCH | `/api/v1/service_orders/:id` | Exibir / atualizar ordem |
| POST | `/api/v1/service_orders/:id/transitions` | Avançar status da ordem |
| GET | `/api/v1/reports/metrics` | Tempo médio de execução (filtro por data) |

**Abertura de OS**: `POST /api/v1/service_orders` aceita `customer_id`/`vehicle_id` de registros existentes **ou** os objetos `customer`/`vehicle` com os dados completos — cliente é localizado pelo documento (CPF/CNPJ) e veículo pela placa; se não existirem, são criados. Retorna a identificação única (`uuid`) da OS.

**Listagem de OS**: ordenada por prioridade de status — Em Execução > Aguardando Aprovação > Diagnóstico > Recebida — e, dentro do mesmo status, mais antigas primeiro. Ordens finalizadas e entregues não aparecem na listagem (exclusão lógica; continuam consultáveis pelo filtro `status`).

### Cliente (token de CPF obrigatório)

Obtenha o token no API Gateway antes de chamar estas rotas:

```bash
curl -X POST "$GATEWAY_URL/auth/cpf" \
  -H 'content-type: application/json' \
  -d '{"cpf":"111.444.777-35"}'
```

| Método | Caminho | Descrição |
|--------|---------|-----------|
| POST | `/auth/cpf` | Emite token de cliente (Lambda, via API Gateway) |
| GET | `/api/v1/customer/service_orders` | Lista as ordens do cliente autenticado |
| GET | `/api/v1/customer/service_orders/:uuid` | Status da ordem (403 se for de outro cliente) |
| POST | `/api/v1/customer/service_orders/:uuid/approve` | Aprovar orçamento |
| POST | `/api/v1/customer/service_orders/:uuid/reject` | Rejeitar orçamento |

As rotas de aprovação e recusa aceitam **também** o token assinado que vai no
link do e-mail, preservando o fluxo da Fase 2. Um token de administrador é
rejeitado com 401 nestas rotas, e vice-versa — os públicos são separados pelo
claim `aud`. Detalhes e limitações em
[RFC 0003](docs/rfc/0003-estrategia-de-autenticacao.md).

### Admin padrão (seed)

```
email: admin@autorepair.com
senha: admin123456
```

## Ciclo de Vida da Ordem de Serviço

```
received → in_diagnosis → awaiting_approval → approved → in_execution → finished → delivered
                                           ↘ finished (rejected) → delivered
```

### Eventos de transição (admin)

| Status atual | Evento | Próximo status |
|---|---|---|
| `received` | `start_diagnosis` | `in_diagnosis` |
| `in_diagnosis` | `send_for_approval` | `awaiting_approval` |
| `awaiting_approval` | `send_for_approval` | `awaiting_approval` (reenvio — invalida token anterior) |
| `approved` | `start_execution` | `in_execution` |
| `in_execution` | `finalize` | `finished` |
| `finished` | `deliver` | `delivered` |

### Fluxo de aprovação e notificações

1. Atendente envia para aprovação (`send_for_approval`) — a API retorna um `approval_link` com token único (SHA256, TTL 7 dias) e o cliente recebe um **e-mail** com o orçamento e o link
2. Cliente aprova (`POST .../approve`) — ordem vai para `approved`; estoque **não** é movimentado neste momento
3. Atendente aciona `start_execution` — estoque é reservado e itens marcados como executados
4. Se o estoque estiver insuficiente, o erro aparece apenas para o atendente — o cliente nunca vê erros internos de estoque

**A cada mudança de status a API envia um e-mail ao cliente** (de forma assíncrona, via Solid Queue). Em desenvolvimento e na demo Kubernetes os e-mails chegam no Mailpit.

Ao rejeitar, o total é zerado e nenhuma movimentação de estoque é gerada. O veículo ainda transiciona para `delivered` pois está fisicamente na oficina.

Todas as respostas de ordem de serviço incluem o campo `available_events` indicando quais eventos podem ser acionados a partir do status atual.

## Testes

```bash
bundle exec rspec
```

SimpleCov exige ≥ 80% de cobertura nos domínios críticos. O relatório é gerado em `coverage/index.html` (não versionado).

## Análise de Segurança

- `brakeman_report.html` — Brakeman (80+ categorias de vulnerabilidades Rails)
- `bundler_audit_report.txt` — bundler-audit contra ruby-advisory-db

Resultado: **0 vulnerabilidades** encontradas pelas ferramentas automatizadas. Ambas rodam no CI.

## Vídeo demonstrativo

> _Link do vídeo (YouTube/Vimeo) — será adicionado na entrega._

## Ambiente de producao

https://1o3jduiwbi.execute-api.us-east-1.amazonaws.com
