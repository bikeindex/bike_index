# frozen_string_literal: true

# Override the default db:migrate task, so that parallel test databases are created by default
# Skip on CI, because CI doesn't use parallel tests
if Rails.env.development? && ENV["CI"].blank?
  Rake::Task["db:migrate"].enhance do
    puts "Running parallel:migrate for test databases..."
    system("rake parallel:migrate")
    system("rake parallel:prepare")
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
