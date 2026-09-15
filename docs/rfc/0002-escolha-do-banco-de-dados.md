# RFC 0002 — Escolha e modelagem do banco de dados

**Autor:** Igor Santos · **Status:** Aprovado · **Data:** 2026-09-15

## Resumo

Propõe manter **PostgreSQL** como banco do sistema, agora na forma gerenciada
(Amazon RDS), e formaliza os ajustes feitos no modelo relacional.

## Motivação

O enunciado da Fase 1 pedia justificativa para a escolha do banco; o da Fase 3
pede justificativa **formal**, mais os ajustes de modelagem com diagrama ER. O
domínio mudou pouco desde a Fase 1, mas agora há requisitos explícitos de
consistência e performance.

## Por que relacional

O domínio é fortemente relacional e as cardinalidades são rígidas:

- Um cliente tem muitos veículos; um veículo pertence a exatamente um cliente
- Uma ordem de serviço referencia exatamente um cliente e um veículo
- Cada item da ordem aponta para **um serviço ou uma peça**, nunca ambos, nunca
  nenhum
- Cada movimentação de estoque pertence a uma peça

Nenhuma dessas relações tolera inconsistência temporária. Um banco de documentos
exigiria ou duplicação (o cliente dentro de cada OS, com o problema de
atualização) ou referências sem integridade garantida pelo motor.

Mais decisivo: há **duas operações que exigem transação ACID real**.

1. **Início da execução.** Ao transicionar para `in_execution`, o sistema debita
   estoque de cada peça e marca os itens como executados. Se o débito falhar por
   saldo insuficiente na terceira peça, as duas primeiras precisam voltar. Hoje
   isso é uma única transação em `TransitionOrder`.
2. **Abertura da OS.** Cria ou localiza cliente e veículo, cria a ordem, cria os
   itens, calcula o total e registra o status inicial. Falha em qualquer ponto
   não pode deixar uma ordem órfã sem itens.

## Por que PostgreSQL

Entre os relacionais, PostgreSQL foi escolhido por:

- **Check constraints e índices parciais**, ambos usados intensamente no modelo
  (detalhes abaixo). MySQL só passou a validar check constraints na 8.0.16, e
  não tem índice parcial
- **Exclusão lógica sem gem.** O padrão `deleted_at` + índice único parcial
  `WHERE deleted_at IS NULL` permite reaproveitar um CPF ou uma placa depois da
  exclusão, mantendo unicidade entre os ativos. Sem índice parcial isso exigiria
  lógica na aplicação
- Continuidade: era o banco das Fases 1 e 2, e migrar introduziria risco sem
  ganho
- `db.t3.micro` no RDS está no free tier e custa US$ 14/mês fora dele

## Ajustes no modelo relacional nesta fase

Migration `20260915000001_add_phase3_consistency_and_performance.rb`.

### Performance

| Índice | Justificativa |
|---|---|
| `index_service_orders_open_queue` em `(status, created_at)` `WHERE status NOT IN ('finished','delivered')` | A listagem de OS é a query mais quente do sistema e já exclui finalizadas e entregues. Um índice parcial cobre exatamente essa consulta e não cresce com o histórico — ordens entregues, que só acumulam, ficam fora do índice |
| `index_service_orders_on_customer_id_and_created_at` | Suporta o novo endpoint de listagem por cliente autenticado, que ordena por data |
| `index_customers_on_document` | O índice existente é parcial (`WHERE deleted_at IS NULL`). A Lambda consulta por `document` **sem** filtrar `deleted_at`, porque precisa distinguir "não existe" de "inativo" — e o planejador não usa índice parcial quando a query não implica o predicado. Sem este índice, cada autenticação faria sequential scan |

### Consistência

Constraints movidas da aplicação para o banco, para que nenhuma escrita fora do
Rails (script de manutenção, migração de dados) possa violá-las:

| Constraint | Regra |
|---|---|
| `chk_service_orders_status` | `status` restrito aos sete estados da máquina de estados |
| `chk_customers_kind` | `kind` em `individual` ou `company` |
| `chk_stock_movements_type` | `movement_type` nos quatro tipos válidos |
| `chk_vehicles_year_range` | Ano entre 1900 e 2100 |
| `chk_service_orders_total_non_negative` | Total nunca negativo |
| `chk_service_order_items_prices_non_negative` | Preço unitário e total nunca negativos |
| `chk_parts_price_non_negative`, `chk_services_price_non_negative` | Preços de catálogo nunca negativos |

Já existiam da Fase 1 e foram mantidas: `chk_item_quantity` (quantidade > 0) e
`chk_item_has_one_ref`, que garante no banco a regra de que um item aponta para
um serviço **ou** uma peça.

### Mudança considerada e recusada

Converter `service_orders.uuid` de `varchar` para o tipo nativo `uuid` economiza
21 bytes por linha e acelera comparações. Foi recusado: o tipo nativo rejeita
strings malformadas com erro de sintaxe SQL, então `find_by(uuid: "abc")`
passaria a lançar exceção em vez de retornar `nil`, transformando um 404 legítimo
em erro 500. O ganho não justifica reescrever o tratamento de erro de todas as
rotas públicas.

## Riscos

| Risco | Mitigação |
|---|---|
| Instância única, sem Multi-AZ — indisponibilidade da AZ derruba o banco | Aceito conscientemente: Multi-AZ dobra o custo e a fase não exige RPO/RTO |
| Dois ambientes (`prod` e `homolog`) na mesma instância | Bancos separados, credenciais iguais. Aceitável para homologação; em produção real seriam instâncias distintas |
| `db.t3.micro` satura sob carga | O teste de carga do HPA bate em endpoints de leitura; se o banco virar gargalo antes da CPU dos pods, subir para `db.t3.small` |
