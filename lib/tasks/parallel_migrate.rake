# frozen_string_literal: true

# Override the default db:migrate task, so that parallel test databases are created by default
# Skip on CI, because CI doesn't use parallel tests
if Rails.env.development? && ENV["SKIP_PARALLEL_MIGRATIONS"].blank?
  # number parallel databases correctly
  ENV["PARALLEL_TEST_FIRST_IS_1"] = "true"

  Rake::Task["db:migrate"].enhance do
    puts "Running parallel:migrate for test databases..."
    system("rake parallel:migrate")
    system("rake parallel:prepare")

    # Remove postgres 17 additions that cause CI failures
    Dir.glob("db/*.sql").each do |file|
      content = File.read(file)
      cleaned = content.lines.reject { |line|
        line.include?("SET transaction_timeout = 0;") ||
          line.start_with?("\\restrict ") ||
          line.start_with?("\\unrestrict ")
      }.join
      File.write(file, cleaned) if cleaned != content
    end
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
