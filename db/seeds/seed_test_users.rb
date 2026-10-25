# Seed test users
# Note: you have to seed the users first, or else the bikes don't have anywhere to go.
#
# Idempotent, keyed on email: sandbox/review databases are long-lived and only
# seed on first boot, so bin/docker-entrypoint re-runs this every deploy to
# (re)create any account missing from databases that already exist.

user_attrs = {
  admin: {name: "Admin User", email: "admin@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true, vendor_terms_of_service: true, when_vendor_terms_of_service: Time.current},
  dev: {name: "Dev User", email: "dev@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true, vendor_terms_of_service: true, when_vendor_terms_of_service: Time.current, developer: true},
  member: {name: "Member User", email: "member@brakebills.edu", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true, vendor_terms_of_service: true, when_vendor_terms_of_service: Time.current},
  user: {name: "Test User", email: "user@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true},
  transfer_recipient: {name: "Transfer Recipient", email: "transfer_recipient@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true},
  transfer_provider: {name: "Transfer Provider", email: "transfer_provider@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true},
  api_accessor: {name: "Api Accessor", email: "api@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true},
  example_user: {name: "Example User", email: "example_user@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true},
  owner: {name: "Owner User", email: "user@fakegmail.com", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true}
}

require File.expand_path("db/seeds/seed_helpers", Rails.root)

user_attrs.values.each do |attributes|
  next if User.find_by_email(attributes[:email])

  SeedHelpers.tick
  new_user = User.create! attributes
  new_user.confirm(new_user.confirmation_token)
  new_user.save
end

# dev is a superuser too - some admin pages require both
user_attrs.values_at(:admin, :dev).each do |attributes|
  SuperuserAbility.find_or_create_by!(user: User.find_by(email: attributes[:email]))
end

# Group gate rather than per-actor — opting out writes users.feature_registration_show_legacy
Flipper.enable_group(:bike_show_redesign_toggle, :superusers)

puts "Users added successfully\n"
