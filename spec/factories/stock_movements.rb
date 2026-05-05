FactoryBot.define do
  factory :stock_movement, class: "Inventory::Entities::StockMovement" do
    association :part,              factory: :part
    association :performed_by_user, factory: :user
    movement_type { "inbound" }
    quantity      { rand(1..50) }
    reason        { "purchase" }
  end
end
