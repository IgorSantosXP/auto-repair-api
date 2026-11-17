# Auto Repair API

Backend Rails 8.1 API-only para gerenciamento de uma oficina mecânica. Cobre ordens de serviço, cadastro de clientes/veículos, controle de estoque, fluxo de aprovação de orçamentos e notificação de clientes por e-mail.

## Fase 4: microsserviços e saga

O monolito foi dividido em **três microsserviços**, cada um com repositório, pipeline,
infraestrutura e banco próprios. Este repositório é o **OS Service**:

| Serviço | Responsabilidade | Banco |
|---|---|---|
| **OS Service** (este repositório) | Abertura da OS, clientes e veículos, status e histórico, **orquestração da saga** | PostgreSQL (RDS) |
| [Billing Service](https://github.com/IgorSantosXP/auto-repair-billing-service) | Orçamento, aprovação, pagamento via **Mercado Pago**, estorno | PostgreSQL (RDS próprio) |
| [Execution Service](https://github.com/IgorSantosXP/auto-repair-execution-service) | Estoque de peças, fila e andamento da execução | **DynamoDB** (NoSQL) |

- **Comunicação**: REST síncrono só para consultar o catálogo de peças ao abrir a OS.
  Todo o resto é **assíncrono via SNS + SQS**, com transactional outbox, consumidores
  idempotentes e DLQ. Nenhum serviço acessa o banco de outro.
- **Saga orquestrada** com compensações: pagamento recusado cancela o orçamento, e uma
  execução impossível (sem estoque) estorna o pagamento no Mercado Pago e cancela a OS.
  Estratégia, justificativa, diagramas e garantias estão em
  **[docs/architecture/saga.md](docs/architecture/saga.md)** e no
  [ADR 0007](docs/adr/0007-saga-orquestrada.md).
- **Qualidade**: RSpec + **BDD (Cucumber)** em cada serviço, cobertura mínima de 80%
  e **SonarQube Cloud** com quality gate no CI.
- **CI/CD independente** por serviço: build, testes, qualidade, Terraform do próprio
  serviço e deploy no EKS. A `main` é protegida e só recebe código por Pull Request.
- **Observabilidade**: Datadog com trace distribuído atravessando a mensageria,
  `saga_id` em todos os logs, dashboard da saga e alertas de compensação e de DLQ.

Visão geral dos serviços: [docs/architecture/microservices.md](docs/architecture/microservices.md).
Índice de toda a documentação: [docs/](docs/).

<details>
<summary>Fase 3: objetivos e solução</summary>

- **API Gateway**: ponto único de entrada, com throttling e log de acesso. Roteia a autenticação para uma Lambda e o restante para o cluster via VPC Link
- **Autenticação por CPF**: função serverless valida o CPF, confirma o cliente na base e emite um JWT de cliente, com público (`aud`) distinto do token de administrador
- **AWS**: EKS com HPA, RDS PostgreSQL gerenciado, ECR e Secrets Manager, tudo provisionado por Terraform
- **Repositórios separados**: Lambda, infraestrutura Kubernetes, infraestrutura de banco e aplicação, cada um com CI/CD, `main` protegida e deploy automático por OIDC
- **Observabilidade**: Datadog com APM, métricas de negócio, logs estruturados em JSON e correlação de requisição ponta a ponta
- **Modelo de dados**: índices e constraints novos para consistência e performance, documentados com diagrama ER

</details>

## Desenho da arquitetura

```
Cliente → API Gateway ─┬─ POST /auth/cpf          → Lambda → RDS (OS)
                       ├─ /api/v1/budgets|payments, /webhooks/mercadopago → NLB:8081 → Billing   → RDS (Billing)
                       ├─ /api/v1/parts|executions → NLB:8082 → Execution → DynamoDB
                       └─ demais /api/*            → NLB:80   → OS Service → RDS (OS)

OS worker ⇄ SNS auto-repair-<env>-events ⇄ SQS (os | billing | execution, cada uma com DLQ) ⇄ workers
Todos → Datadog (APM, logs, métricas)
```

Diagrama completo em [docs/architecture/microservices.md](docs/architecture/microservices.md).
A visão de nuvem da fase 3 (rede, subnets, custos) continua em
[docs/architecture/component-diagram.md](docs/architecture/component-diagram.md).

- **Subnets públicas**: nós do EKS, com IP público para alcançar ECR e a API do cluster
- **Subnets privadas**: RDS, Lambda e o NLB interno, sem rota para a internet. Não há NAT Gateway, o que economiza US$ 32/mês sem expor o banco
- **Dois ambientes** no mesmo cluster: `prod` (branch `main`) e `homolog` (branch `homolog`), com namespaces, filas e bancos separados por serviço

## Stack

- **Ruby 3.4.3** / **Rails 8.1**: API-only, com Solid Queue para jobs assíncronos (e-mails)
- **PostgreSQL 16** no **Amazon RDS**: índices únicos parciais e CHECK constraints
- **SNS + SQS** (LocalStack em desenvolvimento): mensageria da saga, com outbox e DLQ
- **Node.js 22**: função Lambda de autenticação por CPF
- **JWT HS256**: dois públicos, administrador (TTL 24h) e cliente (TTL 1h)
- **RSpec**, **Cucumber** (BDD) e **rswag**: os testes geram a documentação OpenAPI
- **SonarQube Cloud**: cobertura, code smells e quality gate no CI
- **AWS**: EKS, API Gateway, Lambda, RDS, ECR, SNS, SQS e Secrets Manager, provisionados com **Terraform**
- **Datadog**: APM com trace distribuído, métricas customizadas via DogStatsD e logs JSON com `lograge`
- **GitHub Actions**: CI/CD em todos os repositórios, autenticando por OIDC
- **Mailpit**: SMTP de demonstração com UI web

## Arquitetura da aplicação

O projeto segue **Clean Architecture**, organizada em contextos delimitados (DDD) em `app/domains/`:

```
app/domains/
  identity/        # Usuário, JWT, caso de uso de autenticação
  registries/      # Cliente, Veículo, Serviço; value objects CPF/CNPJ/placa
  service_orders/  # Ciclo da OS: máquina de estados, abertura, entrega, notificação
    orchestration/ # Saga: orquestrador, comandos enviados e handlers dos eventos
    gateways/      # Cliente REST do catálogo de peças (Execution Service)
  reports/         # Queries de métricas
app/lib/messaging/ # Envelope, outbox, publisher SNS, consumer SQS, idempotência
```

Mapeamento das camadas:

| Camada (Clean Architecture) | No projeto |
|---|---|
| **Entities**: regras de negócio corporativas | `app/domains/*/entities`, `value_objects` (CPF, CNPJ, placa, status) e `services` de domínio (máquina de estados) |
| **Use Cases**: regras de negócio da aplicação | `app/domains/*/use_cases` (abertura, atualização e entrega da OS, autenticação), o orquestrador da saga e as `queries` |
| **Interface Adapters**: conversão de dados | `app/controllers` (REST/JSON, controllers finos que devolvem um objeto `Result`), handlers de mensagens, gateway do catálogo, mailers |
| **Frameworks & Drivers**: detalhes | Rails, PostgreSQL, SNS/SQS, SMTP, Solid Queue, JWT |

A regra de dependência aponta para dentro: controllers e handlers de mensagem dependem
de use cases, que dependem de entidades, nunca o contrário. A comunicação entre camadas
usa o objeto `Result` (sucesso ou falha, com payload ou erros). Efeitos de borda, como
e-mail, publicação de mensagem e chamada HTTP a outro serviço, ficam atrás de serviços
e gateways, o que mantém os use cases testáveis e o framework substituível.

## Documentação arquitetural

Índice completo em **[docs/](docs/)**.

| Documento | Assunto |
|---|---|
| [Microsserviços](docs/architecture/microservices.md) | **Fase 4**: serviços, bancos, mensageria e infraestrutura |
| [Saga](docs/architecture/saga.md) | **Fase 4**: estratégia, fluxo, estados, compensações e garantias |
| [Componentes](docs/architecture/component-diagram.md) | Visão de nuvem e fluxo de deploy |
| [Sequência: autenticação por CPF](docs/architecture/sequence-auth-cpf.md) | Do CPF ao token, e do token à rota protegida |
| [ADRs](docs/adr/) | EKS, API Gateway, comunicação, HPA, repositórios, **microsserviços, saga e mensageria** |
| [RFCs](docs/rfc/) | Escolha da nuvem, do banco e da estratégia de autenticação |
| [Modelo de dados](docs/database/er-diagram.md) | Diagrama ER e relacionamentos |

## Execução local

### Só o OS Service

```bash
docker compose up --build
docker compose exec api bin/rails db:prepare db:seed
```

- API: `http://localhost:3000`
- Swagger UI: `http://localhost:3000/api-docs`
- Mailpit (e-mails enviados): `http://localhost:8025`

O seed cria o admin, o catálogo de serviços, clientes com CPF válido e ordens em
status diferentes. Os CPFs são impressos no final, para uso no endpoint de autenticação.

### Os três serviços com a saga

Clone os três repositórios lado a lado e suba o compose da saga a partir deste. Ele
sobe as três APIs, os três workers, os dois PostgreSQL, o DynamoDB e o SNS/SQS
(LocalStack) e o Mailpit:

```bash
git clone git@github.com:IgorSantosXP/auto-repair-billing-service.git ../auto-repair-billing-service
git clone git@github.com:IgorSantosXP/auto-repair-execution-service.git ../auto-repair-execution-service

docker compose -f docker-compose.saga.yml -p saga up -d --build
python3 bin/saga-e2e    # percorre o fluxo feliz e o de compensação
```

`bin/saga-e2e` abre uma OS, aprova o orçamento com o token enviado por e-mail, simula
o pagamento, executa e entrega. Depois abre uma OS com peça sem estoque e confere o
estorno e o cancelamento. As portas podem ser trocadas com `OS_PORT`, `BILLING_PORT` e
`EXECUTION_PORT` no compose, e com `OS_URL`, `BILLING_URL` e `EXECUTION_URL` no script.

## Provisionamento da infraestrutura (Terraform)

A ordem de aplicação é **obrigatória**, porque cada repositório lê as saídas do
anterior via estado remoto:

```bash
# 1. rede, cluster, ECR, NLB, API Gateway, tópico SNS   (~15-20 min)
cd auto-repair-infra-k8s && make init && make up && make kubeconfig

# 2. banco do OS Service e segredos                      (~10 min)
cd auto-repair-infra-database && make init && make up

# 3. função de autenticação                              (~2 min)
cd auto-repair-auth-lambda && make init && make up

# 4. infraestrutura própria de cada serviço (fila, DLQ, IAM; RDS do Billing; DynamoDB do Execution)
cd auto-repair-api/terraform && make init && make up
cd auto-repair-billing-service/terraform && make init && make up
cd auto-repair-execution-service/terraform && make init && make up
```

No CI, o passo 4 roda no job de deploy de cada serviço, antes de aplicar os manifestos.

Pré-requisitos: Terraform >= 1.10, AWS CLI com perfil configurado e kubectl.
O bucket de estado remoto precisa existir antes do primeiro `init`. As instruções
estão em [auto-repair-infra-k8s/bootstrap](https://github.com/IgorSantosXP/auto-repair-infra-k8s/tree/main/bootstrap).

> **Custo.** O control plane do EKS custa US$ 0,10/hora e não tem free tier. O ambiente
> é provisionado para testar ou demonstrar e destruído em seguida com `make down`
> em cada repositório, na ordem inversa. O raciocínio está no
> [ADR 0001](docs/adr/0001-eks-como-orquestrador.md).

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
kubectl -n auto-repair-prod rollout status deployment/api deployment/worker
kubectl -n auto-repair-prod exec deploy/api -- bin/rails db:seed
```

O Secret `api-secrets` é criado pelo pipeline a partir do Secrets Manager. Para deploy
manual, crie-o antes com `DATABASE_URL`, `JWT_SECRET` e `SECRET_KEY_BASE`. O tópico e a
fila (`EVENTS_TOPIC_ARN`, `QUEUE_URL`) vêm do ConfigMap gerado por cada overlay.

Os manifestos usam **kustomize**, em [k8s/](k8s/):

- `base/`: Deployment da API (2 réplicas, probes em `/up`, requests/limits), Deployment
  do worker (`bin/rails messaging:work`), ServiceAccount com Pod Identity, Service, HPA
  (2 a 5 réplicas, CPU 70% / memória 80%), Job de migração e Mailpit
- `overlays/prod/`: namespace `auto-repair-prod`, Service NodePort 30080 (alvo do NLB) e imagem do ECR
- `overlays/homolog/`: namespace `auto-repair-homolog`, réplica única e Service interno

A URL pública é a do API Gateway:

```bash
aws apigatewayv2 get-apis --query "Items[?Name=='auto-repair-api'].ApiEndpoint | [0]" --output text
```

### Demonstração do autoscaling

```bash
# terminal 1: acompanhe o HPA
kubectl -n auto-repair-prod get hpa,pods -w

# terminal 2: gere carga contra o API Gateway
./script/load_test.sh "$GATEWAY_URL" 300 40
```

## CI/CD

Pipeline em [.github/workflows/ci.yml](.github/workflows/ci.yml). Billing e Execution
têm o mesmo pipeline, cada um no seu repositório.

| Job | Quando | O que faz |
|---|---|---|
| `security` | PR e push | Brakeman e bundler-audit |
| `test` | PR e push | RSpec + Cucumber com PostgreSQL (SNS/SQS simulados), cobertura mínima de 80% |
| `quality` | PR e push | SonarQube Cloud com o relatório de cobertura e espera o quality gate |
| `manifests` | PR e push | Renderiza e valida os overlays kustomize |
| `deploy` | Push em `main` (prod) ou `homolog` | Terraform do serviço, imagem no ECR, Secret, manifestos, migração, rollout e smoke test no API Gateway |

O job de deploy assume a role `auto-repair-github-actions` por **OIDC**, sem access key
nos secrets do GitHub. Como o ambiente AWS só fica de pé durante testes e demonstrações,
o deploy só roda quando a variável de repositório `DEPLOY_ENABLED` vale `true`. Com o
ambiente no ar, ele pode ser disparado a qualquer momento por *Run workflow*.

A `main` é protegida em todos os repositórios: commits diretos são recusados e o merge
exige pull request com os checks verdes.

## Documentação da API (collection)

- **Swagger UI interativo**: `http://localhost:3000/api-docs`
- **Spec OpenAPI**: [swagger/v1/swagger.yaml](swagger/v1/swagger.yaml), importável no Postman ou Insomnia

Para regenerar a partir dos testes: `bundle exec rake rswag:specs:swaggerize`.
Billing e Execution publicam o próprio Swagger da mesma forma.

## Principais endpoints

### Auth

| Método | Caminho | Descrição |
|--------|---------|-----------|
| POST | `/api/v1/auth/login` | Retorna o token JWT do atendente |

### Atendente (Bearer token obrigatório)

| Método | Caminho | Descrição |
|--------|---------|-----------|
| GET/POST | `/api/v1/customers` | Listar / criar clientes |
| GET/PATCH/DELETE | `/api/v1/customers/:id` | Exibir / atualizar / soft delete |
| GET | `/api/v1/customers/:id/vehicles` | Veículos do cliente |
| GET/POST/PATCH/DELETE | `/api/v1/vehicles` | CRUD de veículos |
| GET/POST/PATCH/DELETE | `/api/v1/services` | CRUD do catálogo de serviços |
| GET/POST | `/api/v1/service_orders` | Listar / abrir ordens de serviço (abre a saga) |
| GET/PATCH | `/api/v1/service_orders/:id` | Exibir / atualizar ordem |
| POST | `/api/v1/service_orders/:id/deliver` | Entregar o veículo (OS finalizada) |
| GET | `/api/v1/service_orders/:id/saga` | Estado da saga e cada mensagem trocada |
| GET | `/api/v1/reports/metrics` | Tempo médio de execução (filtro por data) |

**Abertura de OS**: `POST /api/v1/service_orders` aceita `customer_id`/`vehicle_id` de
registros existentes **ou** os objetos `customer`/`vehicle` completos. O cliente é
localizado pelo documento (CPF/CNPJ) e o veículo pela placa, e são criados se não
existirem. As peças são validadas no catálogo do Execution Service. A resposta traz o
`uuid` da OS e a saga começa pedindo o orçamento ao Billing.

**Listagem de OS**: ordenada por prioridade de status (Em Execução > Aguardando Aprovação >
Diagnóstico > Recebida) e, dentro do mesmo status, das mais antigas para as mais novas.
Ordens finalizadas e entregues não aparecem na listagem, mas continuam consultáveis pelo
filtro `status`.

Orçamento, aprovação e pagamento ficam no
[Billing Service](https://github.com/IgorSantosXP/auto-repair-billing-service). Peças,
estoque e andamento da execução ficam no
[Execution Service](https://github.com/IgorSantosXP/auto-repair-execution-service).
Todos atrás do mesmo API Gateway.

### Cliente (token de CPF obrigatório)

Obtenha o token no API Gateway antes de chamar estas rotas:

```bash
curl -X POST "$GATEWAY_URL/auth/cpf" \
  -H 'content-type: application/json' \
  -d '{"cpf":"111.444.777-35"}'
```

| Método | Caminho | Descrição |
|--------|---------|-----------|
| POST | `/auth/cpf` | Emite o token de cliente (Lambda, via API Gateway) |
| GET | `/api/v1/customer/service_orders` | Lista as ordens do cliente autenticado |
| GET | `/api/v1/customer/service_orders/:uuid` | Status da ordem (403 se for de outro cliente) |

A aprovação ou recusa do orçamento é feita no Billing, pelo link do e-mail ou com o
token de cliente. Um token de administrador é rejeitado com 401 nas rotas de cliente,
e vice-versa, porque os públicos são separados pelo claim `aud`. Detalhes em
[RFC 0003](docs/rfc/0003-estrategia-de-autenticacao.md).

### Admin padrão (seed)

```
email: admin@autorepair.com
senha: admin123456
```

## Ciclo de vida da ordem de serviço

Desde a fase 4 o status da OS é conduzido pela saga, a partir dos eventos de Billing e
Execution:

```
received → awaiting_approval → awaiting_payment → approved → in_diagnosis → in_execution → finished → delivered
     ↘ cancelled (orçamento recusado, pagamento recusado ou execução impossível com estorno)
```

| Status | Quando |
|---|---|
| `received` | OS aberta, orçamento pedido ao Billing |
| `awaiting_approval` | Orçamento gerado e enviado ao cliente por e-mail |
| `awaiting_payment` | Cliente aprovou, link de pagamento do Mercado Pago gerado |
| `approved` | Pagamento confirmado, execução pedida ao Execution (reserva atômica de estoque) |
| `in_diagnosis` / `in_execution` | Mecânico iniciou o diagnóstico / o reparo |
| `finished` | Execução concluída |
| `delivered` | Veículo entregue (`POST .../deliver`) |
| `cancelled` | Recusa do cliente, pagamento recusado ou falta de estoque (pagamento estornado) |

O detalhe de cada passo, comando, evento e compensação está em
[docs/architecture/saga.md](docs/architecture/saga.md).

**A cada mudança de status o cliente recebe um e-mail** (assíncrono, via Solid Queue).
Em desenvolvimento e na demo no Kubernetes os e-mails chegam no Mailpit.

## Testes

```bash
bundle exec rspec       # unitários, requests e contratos de mensagem
bundle exec cucumber    # BDD: features/saga_ordem_de_servico.feature
```

- **Cobertura: 94,94%** (SimpleCov, mínimo exigido de 80%). O relatório fica em
  `coverage/` (não versionado) e é enviado ao SonarQube Cloud pelo CI.
- **BDD** com 4 cenários da saga: fluxo completo até a entrega, compensação por falta
  de estoque (estorno e cancelamento), recusa do orçamento pelo cliente e mensagens
  duplicadas ignoradas.

## Análise de segurança

- `brakeman_report.html`: Brakeman (mais de 80 categorias de vulnerabilidades Rails)
- `bundler_audit_report.txt`: bundler-audit contra o ruby-advisory-db

Resultado: **0 vulnerabilidades** encontradas pelas ferramentas automatizadas. Ambas rodam no CI.

## Vídeo demonstrativo

> _Link do vídeo (YouTube/Vimeo), adicionado na entrega._
