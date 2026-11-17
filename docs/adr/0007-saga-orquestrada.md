# ADR 0007: Saga orquestrada pelo OS Service

**Status:** Aceito · **Data:** 2026-11-16

## Contexto

Abrir, orçar, cobrar e executar uma OS altera dados em três bancos diferentes
([ADR 0006](0006-microsservicos-com-banco-por-servico.md)). Não dá para usar uma
transação distribuída: não há 2PC entre PostgreSQL, DynamoDB e Mercado Pago, e ela
travaria recursos durante a espera pela aprovação do cliente, que pode levar dias. Ainda
assim, falhas no meio do caminho não podem deixar o sistema inconsistente. Por exemplo,
um cliente que pagou por um serviço que não pode ser executado por falta de peça.

## Decisão

Usar o **Saga Pattern na forma orquestrada**, com o **OS Service como orquestrador**:

- O estado da saga e cada mensagem enviada ou recebida ficam no banco do OS Service
  (`sagas` e `saga_steps`), expostos em `GET /api/v1/service_orders/:id/saga`.
- Billing e Execution recebem **comandos** e respondem com **eventos**. Não conhecem o fluxo.
- Toda ação que pode precisar ser desfeita tem uma compensação:

| Passo | Compensação |
|---|---|
| Orçamento gerado e aprovado | `billing.cancel_budget` (invalida orçamento e link) |
| Pagamento confirmado | `billing.refund_payment` (estorno no Mercado Pago) |
| Estoque reservado | Pivô: reserva atômica de todas as peças ou nenhuma, então não sobra estado parcial |

O detalhamento, com diagramas de sequência e de estados, está em
[docs/architecture/saga.md](../architecture/saga.md).

## Justificativa (orquestração × coreografia)

- **O fluxo é sequencial e tem um dono natural.** A OS é o agregado que o cliente
  acompanha. Cada passo depende do anterior: só se cobra depois da aprovação e só se
  executa depois do pagamento.
- **Compensação explícita.** O orquestrador sabe o que já aconteceu e decide o que
  desfazer. Com coreografia, o Billing teria que ouvir falhas do Execution para estornar,
  e o Execution teria que ouvir pagamentos do Billing, criando acoplamento entre os
  participantes.
- **Observabilidade.** Um único lugar responde "em que passo está esta OS e por quê", e
  um único `saga_id` correlaciona logs e traces dos três serviços.
- **Testabilidade.** A máquina de estados é testada isoladamente (RSpec) e o fluxo
  completo em BDD (Cucumber), com os eventos simulados.

## Consequências

- O OS Service concentra a lógica do fluxo. Isso é aceitável porque ele já era o dono do
  ciclo de vida da OS.
- Consistência eventual: a OS mostra `awaiting_payment` até o evento de pagamento
  chegar, o que é natural para o usuário.
- Falha de compensação (estorno recusado) não tem passo automático seguro. A saga vai
  para `compensation_failed` e dispara um alerta no Datadog para tratamento manual.
