# Seed test users
# Note: you have to seed the users first, or else the bikes don't have anywhere to go.

user_attrs = {
  admin: {name: "Admin User", email: "admin@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true, vendor_terms_of_service: true, when_vendor_terms_of_service: Time.current},
  dev: {name: "Dev User", email: "dev@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true, vendor_terms_of_service: true, when_vendor_terms_of_service: Time.current, developer: true},
  member: {name: "Member User", email: "member@brakebills.edu", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true, vendor_terms_of_service: true, when_vendor_terms_of_service: Time.current},
  user: {name: "Test User", email: "user@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true},
  api_accessor: {name: "Api Accessor", email: "api@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true},
  example_user: {name: "Example User", email: "example_user@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true}
}

user_attrs.values.each do |attributes|
  new_user = User.create! attributes
  new_user.confirm(new_user.confirmation_token)
  new_user.save
end

# dev is a superuser too - some admin pages require both
user_attrs.values_at(:admin, :dev).each do |attributes|
  SuperuserAbility.create!(user: User.find_by(email: attributes[:email]))
end

# Group gate rather than per-actor — opting out writes users.feature_registration_show_legacy
Flipper.enable_group(:bike_show_redesign_toggle, :superusers)

puts "Users added successfully\n"
