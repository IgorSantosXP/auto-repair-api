# Diagrama de sequência — abertura e ciclo de vida da ordem de serviço

```mermaid
sequenceDiagram
    autonumber
    actor AD as Atendente
    participant G as API Gateway
    participant A as API Rails
    participant UC as CreateOrder
    participant D as RDS PostgreSQL
    participant T as Telemetry
    actor C as Cliente
    participant M as Mailpit (SMTP)

    AD->>G: POST /api/v1/service_orders<br/>Authorization: Bearer (admin)
    G->>A: via VPC Link
    A->>A: verifica assinatura, aud=admin

    A->>UC: call(params, performed_by: admin)

    Note over UC,D: Tudo dentro de uma única transação

    UC->>D: BEGIN
    UC->>D: busca ou cria cliente por documento
    UC->>D: busca ou cria veículo por placa
    UC->>D: INSERT service_orders (status: received)
    UC->>D: INSERT service_order_items

    alt item sem serviço nem peça, ou com ambos
        D-->>UC: viola chk_item_has_one_ref
        UC->>D: ROLLBACK
        UC-->>A: Result.failure
        A-->>AD: 422
    else itens válidos
        UC->>D: UPDATE total_cents (BudgetCalculator)
        UC->>D: INSERT status_change (nil → received)
        UC->>D: COMMIT
        UC->>T: service_order.created
        UC-->>A: Result.success(order)
        A-->>AD: 201 { uuid, status, total_cents }
    end

    Note over AD,C: Diagnóstico e envio do orçamento

    AD->>A: POST /service_orders/{id}/transitions<br/>{ event: "start_diagnosis" }
    A->>D: status → in_diagnosis
    A->>T: status_changed + duração em "received"

    AD->>A: POST /service_orders/{id}/transitions<br/>{ event: "send_for_approval" }
    A->>A: gera token de aprovação<br/>guarda apenas o digest
    A->>D: status → awaiting_approval
    A->>T: status_changed + duração em "in_diagnosis"
    A->>M: e-mail com orçamento e links<br/>(deliver_later)
    M-->>C: orçamento com link de aprovar/recusar

    alt cliente aprova
        C->>G: POST /customer/service_orders/{uuid}/approve<br/>token do link ou Bearer de CPF
        G->>A: via VPC Link
        A->>A: compara digest do token<br/>verifica expiração
        A->>D: status → approved
        A-->>C: 200

        AD->>A: transitions { event: "start_execution" }
        Note over A,D: Débito de estoque na mesma transação
        A->>D: BEGIN
        A->>D: INSERT stock_movements (outbound) por peça

        alt saldo insuficiente em qualquer peça
            A->>D: ROLLBACK
            A->>T: integration.error
            A-->>AD: 422 saldo insuficiente
        else estoque suficiente
            A->>D: UPDATE items SET executed = true
            A->>D: status → in_execution
            A->>D: COMMIT
            A-->>AD: 200
        end

        AD->>A: transitions { event: "finalize" }
        A->>D: status → finished
        AD->>A: transitions { event: "deliver" }
        A->>D: status → delivered
    else cliente recusa
        C->>G: POST /customer/service_orders/{uuid}/reject
        G->>A: via VPC Link
        A->>D: total_cents = 0, status → finished
        Note over A,D: Sem movimentação de estoque
        A-->>C: 200
    end
```

## Máquina de estados

```mermaid
stateDiagram-v2
    [*] --> received: create
    received --> in_diagnosis: start_diagnosis
    in_diagnosis --> awaiting_approval: send_for_approval
    awaiting_approval --> approved: approve
    awaiting_approval --> finished: reject
    awaiting_approval --> awaiting_approval: send_for_approval
    approved --> in_execution: start_execution
    in_execution --> finished: finalize
    finished --> delivered: deliver
    delivered --> [*]
```

Transições inválidas são rejeitadas pela `StateMachine` antes de tocar o banco, e
a constraint `chk_service_orders_status` garante no PostgreSQL que nenhuma
escrita externa introduza um estado fora dessa lista.

## Onde nascem as métricas do dashboard

| Métrica no Datadog | Origem |
|---|---|
| `auto_repair.service_order.created` | `CreateOrder`, após o commit |
| `auto_repair.service_order.status_changed` | `TransitionOrder`, com tags `from`, `to` e `event` |
| `auto_repair.service_order.status_duration` | `TransitionOrder`, diferença até a transição anterior, com tag do status que terminou |
| `auto_repair.integration.error` | Falhas de reserva de estoque e de envio de e-mail |

A duração é calculada a partir de `service_order_status_changes`, que já
registrava o histórico desde a Fase 1.
