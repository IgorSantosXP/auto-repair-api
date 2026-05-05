FactoryBot.define do
  factory :service_order, class: "ServiceOrders::Entities::ServiceOrder" do
    association :customer
    association :vehicle
    status      { "received" }
    total_cents { 0 }
  end

  factory :service_order_item, class: "ServiceOrders::Entities::ServiceOrderItem" do
    association :service_order
    quantity         { 1 }
    unit_price_cents { 5000 }
    total_cents      { 5000 }
    executed         { false }

    trait :with_service do
      association :service
      part { nil }
    end

    trait :with_part do
      association :part
      service { nil }
    end
  end
end
