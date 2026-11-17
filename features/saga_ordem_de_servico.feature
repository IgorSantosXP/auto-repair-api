# language: pt
Funcionalidade: Saga orquestrada da ordem de serviço
  Como atendente da oficina
  Quero que a OS avance automaticamente conforme Billing e Execution respondem
  Para que orçamento, pagamento e execução fiquem consistentes entre os microsserviços

  Contexto:
    Dado que estou autenticado como atendente
    E existe um cliente com veículo cadastrado
    E o serviço "Troca de pastilhas" custa R$ 100,00
    E a peça "pastilha-freio" custa R$ 180,00 no catálogo do Execution Service

  Cenário: Fluxo completo da abertura à entrega
    Quando eu abro uma OS com o serviço "Troca de pastilhas" e 2 unidades da peça "pastilha-freio"
    Então a OS deve estar "received" com total de R$ 460,00
    E a saga deve estar "budget_requested"
    E o comando "billing.generate_budget" deve ter sido enviado para "billing"
    Quando o Billing Service publicar "billing.budget_generated"
    Então a OS deve estar "awaiting_approval"
    Quando o Billing Service publicar "billing.budget_approved"
    Então a OS deve estar "awaiting_payment"
    E o link de pagamento deve estar disponível para o cliente
    Quando o Billing Service publicar "billing.payment_confirmed"
    Então a OS deve estar "approved"
    E o comando "execution.start" deve ter sido enviado para "execution"
    Quando o Execution Service publicar "execution.queued"
    E o Execution Service publicar "execution.diagnosis_started"
    E o Execution Service publicar "execution.repair_started"
    E o Execution Service publicar "execution.finished"
    Então a OS deve estar "finished"
    E a saga deve estar "completed"
    Quando eu entregar o veículo ao cliente
    Então a OS deve estar "delivered"

  Cenário: Compensação quando falta estoque na execução
    Dado que existe uma OS com pagamento confirmado
    Quando o Execution Service publicar "execution.failed" por falta de estoque
    Então a saga deve estar "compensating"
    E o comando "billing.refund_payment" deve ter sido enviado para "billing"
    E a OS deve estar "approved"
    Quando o Billing Service publicar "billing.payment_refunded"
    Então a saga deve estar "compensated"
    E a OS deve estar "cancelled"
    E o cliente deve ser avisado do cancelamento com estorno

  Cenário: Cliente recusa o orçamento
    Quando eu abro uma OS com o serviço "Troca de pastilhas" e 2 unidades da peça "pastilha-freio"
    E o Billing Service publicar "billing.budget_generated"
    E o Billing Service publicar "billing.budget_rejected"
    Então a saga deve estar "failed"
    E a OS deve estar "cancelled"

  Cenário: Mensagens duplicadas são ignoradas
    Quando eu abro uma OS com o serviço "Troca de pastilhas" e 2 unidades da peça "pastilha-freio"
    E o Billing Service publicar "billing.budget_generated" duas vezes com o mesmo id
    Então a saga deve ter registrado 1 evento recebido
