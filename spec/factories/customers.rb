def generate_cnpj
  base = Array.new(8) { rand(9) } + [0, 0, 0, 1]
  w1   = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
  d1   = (base.zip(w1).sum { |d, w| d * w } % 11).then { |r| r < 2 ? 0 : 11 - r }
  w2   = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
  d2   = ((base + [d1]).zip(w2).sum { |d, w| d * w } % 11).then { |r| r < 2 ? 0 : 11 - r }
  (base + [d1, d2]).join
end

FactoryBot.define do
  factory :customer, class: "Registries::Entities::Customer" do
    kind     { "individual" }
    document { Faker::IdNumber.brazilian_citizen_number }
    name     { Faker::Name.name }
    email    { Faker::Internet.unique.email }
    phone    { Faker::PhoneNumber.phone_number }

    trait :company do
      kind     { "company" }
      document { generate_cnpj }
    end
  end
end
