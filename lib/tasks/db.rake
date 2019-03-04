namespace :db do
  desc "Creates an anonymized db dump"
  task :anon_dump do
    puts "[+] Creating anon dump: #{dump_path}. Can take ~8 minutes."
    system "pg_dump --verbose --clean --no-owner --no-acl --dbname #{config['database']} | bundle exec fake_pipe > #{dump_path}"
  end

  desc "Creates a fresh db from an anonymized database dump."
  task :anon_restore do
    puts "[+] Creating fresh database from dump: #{dump_path}."
    Rake::Task["db:drop"].invoke
    Rake::Task["db:create"].invoke
    system "psql -d #{config['database']} -f #{dump_path}"
  end

  desc "Updates an anon user with credentials for development."
  task setup_anon_user: :environment do
    anon_user = User
    .joins(:owned_bikes)
    .group("users.id").having("count('owned_bikes') > 100")
    .first

    anon_attrs = { username: "tester123", email: "tester123@example.com", password: "secret" }
    anon_user.update_attributes!(anon_attrs)
    puts "[+] Setup anon user: #{anon_attrs.inspect}"
  end

  private

  def config
    Rails.configuration.database_configuration[Rails.env]
  end

  def dump_path
    ENV['DUMP_PATH'] || Rails.root.join('db/anon.psql').to_path
  end
end