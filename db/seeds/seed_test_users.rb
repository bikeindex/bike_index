# Seed test users
# Note: you have to seed the users first, or else the bikes don't have anywhere to go.
#
# Idempotent, keyed on email: sandbox/review databases are long-lived and only
# seed on first boot, so bin/docker-entrypoint re-runs this every deploy to
# create any account missing from databases that already exist. An existing
# account, deleted included, is left alone, superuser ability and all.

require File.expand_path("db/seeds/seed_helpers", Rails.root)

user_attrs = {
  admin: {name: "Admin User", email: "admin@bikeindex.org", vendor_terms_of_service: true, when_vendor_terms_of_service: Time.current},
  dev: {name: "Dev User", email: "dev@bikeindex.org", vendor_terms_of_service: true, when_vendor_terms_of_service: Time.current, developer: true},
  member: {name: "Member User", email: "member@brakebills.edu", vendor_terms_of_service: true, when_vendor_terms_of_service: Time.current},
  user: {name: "Test User", email: "user@bikeindex.org"},
  transfer_recipient: {name: "Transfer Recipient", email: "transfer_recipient@bikeindex.org"},
  transfer_provider: {name: "Transfer Provider", email: "transfer_provider@bikeindex.org"},
  api_accessor: {name: "Api Accessor", email: "api@bikeindex.org"},
  example_user: {name: "Example User", email: "example_user@bikeindex.org"},
  owner: {name: "Owner User", email: "user@fakegmail.com"}
}.transform_values { |attributes| attributes.merge(password: SeedHelpers::PASSWORD, password_confirmation: SeedHelpers::PASSWORD, terms_of_service: true) }

new_user_attrs = user_attrs.reject { |_key, attributes| User.unscoped.exists?(email: attributes[:email]) }

new_user_attrs.each_value do |attributes|
  SeedHelpers.tick
  new_user = User.create! attributes
  new_user.confirm(new_user.confirmation_token)
  new_user.save
end

# dev is a superuser too - some admin pages require both
superuser_attrs = new_user_attrs.values_at(:admin, :dev).compact
superuser_attrs.each do |attributes|
  SuperuserAbility.create!(user: User.find_by(email: attributes[:email]))
end

# Group gate rather than per-actor — opting out writes users.feature_registration_show_legacy
Flipper.enable_group(:bike_show_redesign_toggle, :superusers) if superuser_attrs.any?

puts "Users added successfully\n"
