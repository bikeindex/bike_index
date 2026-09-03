# Seed a local dev / sandbox iOS OAuth application.
#
# Idempotent, keyed on the well-known uid: sandbox/review databases are
# long-lived and only seed on first boot, so bin/docker-entrypoint re-runs this
# every deploy to (re)create the app and repair any drifted attributes.

user = User.find_by_email("user@bikeindex.org")
raise "No user found" unless user.present?

app = Doorkeeper::Application.find_or_initialize_by(uid: "9cBuxnqbhums1vun26ZfMv-91rInzdc6_G9HCulFxKs")
created = app.new_record?
app.update!(
  owner: user,
  name: "Localhost Dev iOS",
  secret: "Tcw_4Cr1-Yowsjs-E2Te0YZnVdYmeES3UJ0AhbeBE10",
  redirect_uri: "bikeindex://",
  scopes: [:read_user, :write_user, :read_bikes, :write_bikes],
  is_internal: true
)

puts "  #{created ? "Created" : "Updated"} OAuth application ##{app.id}: #{app.name} (uid=#{app.uid[0..12]}...)" if Rails.env.development?
puts "Done seeding OAuth application!"
