# Auto Repair API

Backend Rails 8.1 API-only para gerenciamento de uma oficina mecânica. Cobre ordens de serviço, cadastro de clientes/veículos, controle de estoque e fluxo de aprovação de orçamentos.

## Stack

- **Ruby 3.4.3** / **Rails 8.1**
- **PostgreSQL 16** — índices únicos parciais, CHECK constraints, saldo de estoque via CASE-SUM
- **JWT HS256** — autenticação de admins (TTL 24h)
- **RSpec** + **rswag** — testes geram a documentação OpenAPI automaticamente
- **rack-attack** — rate limiting em login e endpoints de clientes

## Arquitetura

O projeto segue DDD por contexto delimitado em `app/domains/`:

```
app/domains/
  identity/        # Usuário, JWT, caso de uso de autenticação
  registries/      # Cliente, Veículo, Serviço — value objects CPF/CNPJ/placa
  inventory/       # Peça, Movimentação de estoque, calculadora de saldo
  service_orders/  # Ciclo completo: máquina de estados, token de aprovação, orçamento
  reports/         # Queries de métricas
```

Controllers são finos — delegam para casos de uso ou chamam o model diretamente e renderizam um objeto `Result`. Casos de uso só existem onde há lógica de negócio real (auth, movimentação de estoque, transições e aprovação de ordem).

### Por que PostgreSQL

- `stock_movements` é um ledger append-only; o saldo é derivado via `SUM(CASE ...)` — sem coluna mutável que possa divergir
- Índices únicos parciais (`WHERE deleted_at IS NULL`) garantem unicidade apenas em registros ativos, viabilizando soft delete sem colisões
- `SELECT FOR UPDATE` nas movimentações evita race condition em saídas concorrentes do mesmo item

## Configuração

### Com Docker (recomendado)

```bash
docker compose up --build
docker compose exec api bin/rails db:create db:migrate db:seed
```

API disponível em `http://localhost:3000`.

### Sem Docker

```bash
# Requer PostgreSQL 16 rodando localmente
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server
```

Defina `JWT_SECRET` no ambiente ou em `config/credentials.yml.enc`.

### Admin padrão (seed)

```
email: admin@autorepair.com
senha: admin123456
```

## Testes

```bash
bundle exec rspec
```

SimpleCov exige ≥ 80% de cobertura nos domínios críticos. O relatório de cobertura é gerado localmente em `coverage/index.html` (não versionado).

## Documentação da API

Inicie o servidor e acesse `http://localhost:3000/api-docs` para o Swagger UI interativo.

Para regenerar o spec OpenAPI a partir dos testes de requisição:

```bash
bundle exec rake rswag:specs:swaggerize
```

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

### Cliente (sem autenticação)

| Método | Caminho | Descrição |
|--------|---------|-----------|
| GET | `/api/v1/customer/service_orders/:uuid` | Status da ordem (visão pública) |
| POST | `/api/v1/customer/service_orders/:uuid/approve` | Aprovar orçamento |
| POST | `/api/v1/customer/service_orders/:uuid/reject` | Rejeitar orçamento |

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

### Fluxo de aprovação

1. Atendente envia para aprovação (`send_for_approval`) — a API retorna um `approval_link` com token único (SHA256, TTL 7 dias)
2. Cliente acessa o link e aprova (`POST .../approve`) — ordem vai para `approved`; estoque **não** é movimentado neste momento
3. Atendente aciona `start_execution` — estoque é reservado e itens marcados como executados; ordem vai para `in_execution`
4. Se o estoque estiver insuficiente, o erro aparece **apenas para o atendente** no passo 3 — o cliente nunca vê erros internos de estoque

Ao rejeitar, o total é zerado e nenhuma movimentação de estoque é gerada. O veículo ainda transiciona para `delivered` pois está fisicamente na oficina.

Todas as respostas de ordem de serviço incluem o campo `available_events` indicando quais eventos podem ser acionados a partir do status atual.

## Análise de Segurança

O diretório raiz contém os relatórios gerados pelas ferramentas de análise estática:

- `brakeman_report.html` — Brakeman 8.0.4 (80+ categorias de vulnerabilidades Rails)
- `bundler_audit_report.txt` — bundler-audit contra ruby-advisory-db (1.078 advisories)

Resultado: **0 vulnerabilidades** encontradas pelas ferramentas automatizadas. Ambas também rodam no CI via GitHub Actions.
