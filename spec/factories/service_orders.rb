FactoryBot.define do
  factory :service_order, class: "ServiceOrders::Entities::ServiceOrder" do
    association :customer
    association :vehicle
    status      { "received" }
    total_cents { 0 }
  end

  factory :service_order_item, class: "ServiceOrders::Entities::ServiceOrderItem" do
    association :service_order
    name             { "Item" }
    quantity         { 1 }
    unit_price_cents { 5000 }
    total_cents      { 5000 }
    executed         { false }

    trait :with_service do
      association :service
      part_id { nil }
    end

    trait :with_part do
      part_id { "oleo-5w30" }
      service { nil }
    end
  end

  factory :saga, class: "ServiceOrders::Entities::Saga" do
    association :service_order
    state { "budget_requested" }
  end
end
