# frozen_string_literal: true

# Strip Postgres 17 pg_dump artifacts (SET transaction_timeout, \restrict,
# \unrestrict) after every schema dump, so structure.sql files stay clean and
# don't fail CI. Runs wherever the schema is dumped (db:migrate, db:schema:dump).
Rake::Task["db:schema:dump"].enhance do
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
