# Seed test users
# Note: you have to seed the users first, or else the bikes don't have anywhere to go.

user_attrs = {
  admin: {name: "admin", email: "admin@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true, vendor_terms_of_service: true, when_vendor_terms_of_service: Time.current, superuser: true, developer: true},
  member: {name: "member", email: "member@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true, vendor_terms_of_service: true, when_vendor_terms_of_service: Time.current},
  user: {name: "user", email: "user@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true},
  api_accessor: {name: "Api Accessor", email: "api@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true},
  example_user: {name: "Example user", email: "example_user@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true}
}

user_attrs.values.each do |attributes|
  new_user = User.create attributes
  new_user.confirm(new_user.confirmation_token)
  new_user.save
end

puts "Users added successfully\n"
