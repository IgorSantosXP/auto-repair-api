# ADR 0006: Três microsserviços, cada um com seu banco

**Status:** Aceito · **Data:** 2026-11-16 · Substitui parcialmente o [ADR 0003](0003-comunicacao-sincrona-rest.md)

## Contexto

Com a expansão da oficina, o monolito da fase 3 passou a concentrar ciclos de mudança
diferentes. Orçamento e pagamento mudam com o gateway de pagamento. Estoque e execução
mudam com a operação da oficina. O ciclo de vida da OS muda com o atendimento. Um deploy
de qualquer uma dessas partes afetava as outras, e o pico de consultas de estoque
escalava a aplicação inteira.

## Decisão

Separar em três serviços, cada um com repositório, pipeline, infraestrutura e banco próprios:

| Serviço | Responsabilidade | Banco | Por quê |
|---|---|---|---|
| **OS Service** ([auto-repair-api](https://github.com/IgorSantosXP/auto-repair-api)) | Abertura da OS, clientes e veículos, status e histórico, orquestração da saga | PostgreSQL (RDS `auto-repair-db` da fase 3, exclusivo do OS) | Dados relacionais com integridade forte (cliente, veículo, OS, itens, histórico) |
| **Billing** ([auto-repair-billing-service](https://github.com/IgorSantosXP/auto-repair-billing-service)) | Orçamento, aprovação, pagamento (Mercado Pago), estorno | PostgreSQL (RDS próprio `auto-repair-billing-db`) | Dinheiro exige transações ACID e auditoria |
| **Execution** ([auto-repair-execution-service](https://github.com/IgorSantosXP/auto-repair-execution-service)) | Catálogo e estoque de peças, fila e andamento da execução | DynamoDB | Acesso por chave e por status, escrita condicional atômica para reservar estoque, escala sob demanda |

Nenhum serviço lê o banco de outro. Há duas formas de integração:

- **REST síncrono**, apenas para consulta em tempo real: o OS Service valida peças e
  preços no catálogo do Execution ao abrir a OS.
- **Mensageria assíncrona** (SNS + SQS) para tudo que muda estado em outro serviço, ver
  [ADR 0008](0008-mensageria-sns-sqs-com-outbox.md).

## Consequências

**Positivas**

- Deploy e escala independentes: cada serviço tem HPA, namespace e pipeline próprios
- Falha isolada: se o Billing cair, OS e Execution continuam atendendo, e os comandos
  esperam na fila
- O banco de cada serviço é escolhido pelo seu padrão de acesso: SQL onde há
  relacionamentos e dinheiro, NoSQL onde há leitura por chave e alta concorrência no estoque

**Negativas**

- Consistência eventual entre serviços, tratada pela saga ([ADR 0007](0007-saga-orquestrada.md))
- Mais componentes para operar: três workers, três filas e DLQs, um RDS extra. Isso é
  mitigado com Terraform por serviço e com dashboards e alertas da saga no Datadog
- Dados duplicados de propósito: o Billing guarda um snapshot do cliente e dos itens no
  momento do orçamento

## Alternativas consideradas

- **Um RDS com schemas por serviço**: mais barato, mas não cumpre o isolamento ("sem
  banco compartilhado") e mantém um ponto único de falha.
- **DynamoDB para o Billing**: perderíamos transações relacionais em pagamento e estorno,
  e as consultas de auditoria por período ficariam mais difíceis.
