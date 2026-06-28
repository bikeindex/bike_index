# frozen_string_literal: true

# Override the default db:migrate task, so that parallel test databases are migrated too.
# Opt-in only: set PARALLEL_MIGRATIONS to enable (e.g. PARALLEL_MIGRATIONS=true bin/rake db:migrate).
# Off by default, since parallel test databases aren't always needed and CI doesn't use them.
if Rails.env.development? && ENV["PARALLEL_MIGRATIONS"].present?
  # number parallel databases correctly
  ENV["PARALLEL_TEST_FIRST_IS_1"] = "true"

  Rake::Task["db:migrate"].enhance do
    puts "Running parallel:migrate for test databases..."
    system("rake parallel:migrate")
    system("rake parallel:prepare")
    # Postgres 17 pg_dump artifacts are stripped by the db:schema:dump enhancement
  end

  Rake::Task["db:drop"].enhance do
    system("rake parallel:drop")
  end

  Rake::Task["db:create"].enhance do
    system("rake parallel:create")
  end

  Rake::Task["db:setup"].enhance do
    system("rake parallel:setup")
  end
end
