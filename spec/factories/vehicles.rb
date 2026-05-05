FactoryBot.define do
  factory :vehicle, class: "Registries::Entities::Vehicle" do
    association :customer
    license_plate { "ABC#{rand(1000..9999)}" }
    brand         { Faker::Vehicle.make }
    model         { Faker::Vehicle.model }
    year          { Faker::Vehicle.year.to_i }
  end
end
