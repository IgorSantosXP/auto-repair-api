FactoryBot.define do
  factory :part, class: "Inventory::Entities::Part" do
    sku              { Faker::Alphanumeric.unique.alphanumeric(number: 8).upcase }
    name             { Faker::Commerce.unique.product_name }
    description      { Faker::Lorem.sentence }
    unit_price_cents { rand(500..20_000) }
    active           { true }
  end
end
