# Seed a local dev iOS OAuth application.

user = User.find_by_email("user@bikeindex.org")
raise "No user found" unless user.present?

app = Doorkeeper::Application.create!(
  owner: user,
  name: "Localhost Dev iOS",
  uid: "9cBuxnqbhums1vun26ZfMv-91rInzdc6_G9HCulFxKs",
  secret: "Tcw_4Cr1-Yowsjs-E2Te0YZnVdYmeES3UJ0AhbeBE10",
  redirect_uri: "bikeindex://",
  scopes: [:read_user, :write_user, :read_bikes, :write_bikes],
  is_internal: true
)

puts "  Created OAuth application ##{app.id}: #{app.name} (uid=#{app.uid[0..12]}...)" if Rails.env.development?
puts "Done seeding OAuth application!"
