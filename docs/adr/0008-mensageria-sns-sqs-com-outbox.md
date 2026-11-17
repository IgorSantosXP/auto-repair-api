# ADR 0008: Mensageria com SNS + SQS, outbox e consumidores idempotentes

**Status:** Aceito · **Data:** 2026-11-16

## Contexto

A saga ([ADR 0007](0007-saga-orquestrada.md)) troca comandos e eventos entre três
serviços. A troca precisa:

- sobreviver à indisponibilidade temporária de qualquer serviço;
- não perder mensagens quando o banco grava mas a publicação falha;
- tolerar mensagens duplicadas ou fora de ordem.

## Decisão

- **Um tópico SNS por ambiente** (`auto-repair-<env>-events`) e **uma fila SQS por
  serviço** (`auto-repair-<env>-<serviço>`). A assinatura usa *raw delivery* e *filter
  policy* pelo atributo `destination`, então cada fila recebe só o que é seu.
- **DLQ por fila**, com `maxReceiveCount = 3`, e alerta no Datadog quando o consumo falha.
- **Envelope único** (`message_id`, `type`, `kind`, `saga_id`, `correlation_id`,
  `service_order_uuid`, contexto de trace, `payload`), igual nos três serviços.
- **Transactional outbox**: a mensagem é gravada na mesma transação da mudança de
  estado (tabela `outbox_messages` no PostgreSQL, ou item na `TransactWriteItems` do
  DynamoDB) e publicada pelo worker.
- **Idempotência**: cada consumidor registra o `message_id` processado
  (`processed_messages`) e ignora repetições.
- **Worker separado** (`bin/rails messaging:work`) em seu próprio Deployment. Ele faz o
  relay do outbox e o long polling da fila, e escala independente da API.
- Acesso à AWS pelos pods via **EKS Pod Identity**: cada serviço só publica no tópico e
  lê a própria fila.

## Consequências

- Entrega *at least once* com efeito *exactly once* graças à idempotência.
- Ordem não garantida: o orquestrador valida o estado esperado e devolve à fila eventos
  que chegaram cedo demais.
- Localmente, o mesmo código roda contra o LocalStack (`MESSAGING_AUTO_PROVISION=true`
  cria tópico, filas e assinaturas).

## Alternativas consideradas

- **EventBridge**: roteamento mais rico, mas não há necessidade dele aqui. SNS + SQS dá
  fila durável e DLQ por consumidor de forma mais simples.
- **Kafka (MSK)**: ordenação e replay, ao custo de um cluster sempre ligado, caro demais
  para o volume da oficina.
- **SQS FIFO**: resolveria a ordem, mas limita o throughput e exige `MessageGroupId`.
  A validação de estado no orquestrador resolve o mesmo problema.
