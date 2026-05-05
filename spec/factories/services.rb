FactoryBot.define do
  factory :service, class: "Registries::Entities::Service" do
    name                       { Faker::Job.unique.title }
    description                { Faker::Lorem.sentence }
    base_price_cents           { rand(1000..50_000) }
    estimated_duration_minutes { [30, 60, 90, 120].sample }
    active                     { true }
  end
end
