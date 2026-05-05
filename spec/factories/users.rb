FactoryBot.define do
  factory :user, class: "Identity::Entities::User" do
    name     { Faker::Name.name }
    email    { Faker::Internet.unique.email }
    password { "password123" }
    role     { "admin" }
  end
end
