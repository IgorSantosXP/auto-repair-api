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

puts "Catalog ready: #{services.size} services (parts live in the Execution Service)"
puts "Customers ready: #{customers.size}"

puts ""
puts "Demo CPFs for POST /auth/cpf:"
CUSTOMERS.each { |c| puts "  #{c[:document]}  #{c[:name]}" }
