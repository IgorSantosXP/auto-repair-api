admin = Identity::Entities::User.find_or_initialize_by(email: "admin@autorepair.com")
admin.assign_attributes(
  name: "Admin",
  role: "admin",
  password: ENV.fetch("SEED_ADMIN_PASSWORD", "admin123456"),
  password_confirmation: ENV.fetch("SEED_ADMIN_PASSWORD", "admin123456")
)
admin.save!
puts "Admin user ready: #{admin.email}"

exit if ENV["SEED_DEMO_DATA"] == "false"

SERVICES = [
  { name: "Troca de óleo",        base_price_cents: 18_000, estimated_duration_minutes: 40 },
  { name: "Alinhamento",          base_price_cents: 12_000, estimated_duration_minutes: 60 },
  { name: "Balanceamento",        base_price_cents: 9_000,  estimated_duration_minutes: 45 },
  { name: "Revisão de freios",    base_price_cents: 35_000, estimated_duration_minutes: 120 },
  { name: "Troca de embreagem",   base_price_cents: 120_000, estimated_duration_minutes: 480 }
].freeze

PARTS = [
  { sku: "OL-5W30",  name: "Óleo sintético 5W30 (litro)", unit_price_cents: 6_500 },
  { sku: "FL-OLEO",  name: "Filtro de óleo",              unit_price_cents: 4_200 },
  { sku: "PS-FREIO", name: "Pastilha de freio (par)",     unit_price_cents: 18_900 },
  { sku: "DS-FREIO", name: "Disco de freio",              unit_price_cents: 27_500 },
  { sku: "KT-EMBR",  name: "Kit de embreagem",            unit_price_cents: 89_000 }
].freeze

CUSTOMERS = [
  { document: "11144477735", name: "Maria Souza",       email: "maria@example.com",  phone: "47999990001",
    vehicle: { license_plate: "ABC1D23", brand: "Volkswagen", model: "Gol",     year: 2019 } },
  { document: "12345678909", name: "João Pereira",      email: "joao@example.com",   phone: "47999990002",
    vehicle: { license_plate: "EFG2H34", brand: "Fiat",       model: "Argo",    year: 2021 } },
  { document: "52998224725", name: "Ana Lima",          email: "ana@example.com",    phone: "47999990003",
    vehicle: { license_plate: "IJK3L45", brand: "Chevrolet",  model: "Onix",    year: 2020 } },
  { document: "39053344705", name: "Carlos Ferreira",   email: "carlos@example.com", phone: "47999990004",
    vehicle: { license_plate: "MNO4P56", brand: "Toyota",     model: "Corolla", year: 2022 } }
].freeze

services = SERVICES.map do |attrs|
  service = Registries::Entities::Service.find_or_initialize_by(name: attrs[:name])
  service.assign_attributes(attrs.merge(active: true))
  service.save!
  service
end

parts = PARTS.map do |attrs|
  part = Inventory::Entities::Part.find_or_initialize_by(sku: attrs[:sku])
  part.assign_attributes(attrs.merge(active: true))
  part.save!

  if Inventory::Services::StockBalanceCalculator.balance_for(part.id) < 20
    Inventory::UseCases::RegisterMovement.call(
      part_id:       part.id,
      movement_type: "inbound",
      quantity:      50,
      reason:        "Estoque inicial",
      performed_by:  admin
    )
  end

  part
end

customers = CUSTOMERS.map do |attrs|
  customer = Registries::Entities::Customer.find_or_initialize_by(document: attrs[:document])
  customer.assign_attributes(
    kind:  "individual",
    name:  attrs[:name],
    email: attrs[:email],
    phone: attrs[:phone]
  )
  customer.save!

  vehicle = Registries::Entities::Vehicle.find_or_initialize_by(license_plate: attrs[:vehicle][:license_plate])
  vehicle.assign_attributes(attrs[:vehicle].merge(customer_id: customer.id))
  vehicle.save!

  [customer, vehicle]
end

puts "Catalog ready: #{services.size} services, #{parts.size} parts"
puts "Customers ready: #{customers.size}"

if ServiceOrders::Entities::ServiceOrder.count.zero?
  targets = [
    { customer_index: 0, events: [],                                              label: "received" },
    { customer_index: 1, events: %w[start_diagnosis],                             label: "in_diagnosis" },
    { customer_index: 2, events: %w[start_diagnosis send_for_approval],           label: "awaiting_approval" },
    { customer_index: 3, events: %w[start_diagnosis send_for_approval],           label: "awaiting_approval" }
  ]

  targets.each_with_index do |target, index|
    customer, vehicle = customers[target[:customer_index]]

    result = ServiceOrders::UseCases::CreateOrder.call(
      {
        customer_id: customer.id,
        vehicle_id:  vehicle.id,
        items: [
          { service_id: services[index % services.size].id, quantity: 1 },
          { part_id:    parts[index % parts.size].id,       quantity: 2 }
        ]
      },
      performed_by: admin
    )

    next unless result.success?

    order = result.payload
    target[:events].each do |event|
      ServiceOrders::UseCases::TransitionOrder.call(order.id, event: event, performed_by: admin)
    end

    puts "  OS #{order.reload.uuid} — #{customer.name} — #{order.status}"
  end
end

puts ""
puts "Demo CPFs for POST /auth/cpf:"
CUSTOMERS.each { |c| puts "  #{c[:document]}  #{c[:name]}" }
