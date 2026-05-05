admin = Identity::Entities::User.find_or_initialize_by(email: "admin@autorepair.com")
admin.assign_attributes(
  name: "Admin",
  role: "admin",
  password: "admin123456",
  password_confirmation: "admin123456"
)
admin.save!
puts "Admin user ready: #{admin.email} / password: admin123456"
