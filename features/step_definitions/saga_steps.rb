def money_to_cents(value)
  (value.delete(".").tr(",", ".").to_f * 100).round
end

def auth_headers
  { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{@token}" }
end

def current_order
  ServiceOrders::Entities::ServiceOrder.find(@order_id)
end

def current_saga
  current_order.saga
end

def deliver(envelope)
  handler     = ServiceOrders::Orchestration::Handlers::REGISTRY.fetch(envelope.type)
  idempotency = Messaging::DatabaseIdempotency.new
  idempotency.once(envelope.message_id) { handler.call(envelope) }
end

def event_payload(type)
  {
    "billing.budget_generated"    => { "budget_id" => "budget-1", "total_cents" => current_order.total_cents },
    "billing.budget_approved"     => { "budget_id" => "budget-1", "payment_url" => "https://mp.example/checkout/1" },
    "billing.budget_rejected"     => { "budget_id" => "budget-1", "reason" => "Muito caro" },
    "billing.payment_confirmed"   => { "payment_id" => "pay-1", "amount_cents" => current_order.total_cents },
    "billing.payment_refunded"    => { "payment_id" => "pay-1", "refund_id" => "refund-1" },
    "execution.queued"            => { "position" => 1 },
    "execution.diagnosis_started" => { "notes" => "Pastilhas gastas" },
    "execution.repair_started"    => {},
    "execution.finished"          => { "notes" => "Serviço concluído" }
  }.fetch(type, {})
end

def publish_event(type, payload = event_payload(type))
  envelope = Messaging::Envelope.event(type, payload: payload, saga_id: current_saga.uuid,
                                             service_order_uuid: current_order.uuid)
  deliver(envelope)
  envelope
end

Dado("que estou autenticado como atendente") do
  @admin = create(:user)
  @token = Identity::Services::JwtEncoder.encode({ "sub" => @admin.id })
end

Dado("existe um cliente com veículo cadastrado") do
  @customer = create(:customer)
  @vehicle  = create(:vehicle, customer: @customer)
end

Dado("o serviço {string} custa R$ {word}") do |name, price|
  create(:service, name: name, base_price_cents: money_to_cents(price))
end

Dado("a peça {string} custa R$ {word} no catálogo do Execution Service") do |part_id, price|
  stub_request(:get, "http://localhost:3002/api/v1/parts/#{part_id}")
    .to_return(status: 200, headers: { "Content-Type" => "application/json" },
               body: { id: part_id, name: "Jogo de pastilhas", unit_price_cents: money_to_cents(price),
                       stock_quantity: 10, active: true }.to_json)
end

Quando("eu abro uma OS com o serviço {string} e {int} unidades da peça {string}") do |service_name, quantity, part_id|
  service = Registries::Entities::Service.find_by!(name: service_name)
  body = {
    customer_id: @customer.id, vehicle_id: @vehicle.id, diagnosis_notes: "Barulho ao frear",
    items: [{ service_id: service.id, quantity: 1 }, { part_id: part_id, quantity: quantity }]
  }
  post "/api/v1/service_orders", body.to_json, auth_headers
  expect(last_response.status).to eq(201), last_response.body
  @order_id = json["id"]
end

Dado("que existe uma OS com pagamento confirmado") do
  step 'eu abro uma OS com o serviço "Troca de pastilhas" e 2 unidades da peça "pastilha-freio"'
  %w[billing.budget_generated billing.budget_approved billing.payment_confirmed].each do |type|
    publish_event(type)
  end
end

Quando("o Billing Service publicar {string}") do |type|
  publish_event(type)
end

Quando("o Execution Service publicar {string}") do |type|
  publish_event(type)
end

Quando("o Execution Service publicar {string} por falta de estoque") do |type|
  publish_event(type, "reason" => "insufficient_stock",
                      "details" => [{ "part_id" => "pastilha-freio", "requested" => 2, "available" => 0 }])
end

Quando("o Billing Service publicar {string} duas vezes com o mesmo id") do |type|
  envelope = publish_event(type)
  @duplicate_result = deliver(envelope)
end

Quando("eu entregar o veículo ao cliente") do
  post "/api/v1/service_orders/#{@order_id}/deliver", nil, auth_headers
  expect(last_response.status).to eq(200), last_response.body
end

Então("a OS deve estar {string} com total de R$ {word}") do |status, total|
  expect(current_order).to have_attributes(status: status, total_cents: money_to_cents(total))
end

Então("a OS deve estar {string}") do |status|
  get "/api/v1/service_orders/#{@order_id}", nil, auth_headers
  expect(json["status"]).to eq(status)
end

Então("a saga deve estar {string}") do |state|
  get "/api/v1/service_orders/#{@order_id}/saga", nil, auth_headers
  expect(json["state"]).to eq(state)
end

Então("o comando {string} deve ter sido enviado para {string}") do |type, destination|
  message = Messaging::OutboxMessage.where(message_type: type).last
  expect(message).to be_present
  expect(message.destination).to eq(destination)
  expect(message.envelope.saga_id).to eq(current_saga.uuid)
end

Então("o link de pagamento deve estar disponível para o cliente") do
  expect(current_saga.payment_url).to eq("https://mp.example/checkout/1")
end

Então("o cliente deve ser avisado do cancelamento com estorno") do
  mail = ActionMailer::Base.deliveries.last
  expect(mail.to).to eq([@customer.email])
  expect(mail.text_part.body.to_s.downcase).to include("refunded")
end

Então("a saga deve ter registrado {int} evento recebido") do |count|
  expect(@duplicate_result).to be(false)
  expect(current_saga.steps.where(direction: "received").count).to eq(count)
end
