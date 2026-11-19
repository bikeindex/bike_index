class RenameRegistrationSequencesToEducationCourses < ActiveRecord::Migration[8.1]
  SLUG_COLUMNS = {"organizations.enabled_feature_slugs" => "jsonb", "invoices.child_enabled_feature_slugs" => "jsonb",
                  "organization_features.feature_slugs" => "text[]"}.freeze

  def up = rename_everything(from: "registration_sequence", to: "education_course")

  def down = rename_everything(from: "education_course", to: "registration_sequence")

  private

  def rename_everything(from:, to:)
    %w[s _pages _acknowledgments].each { rename_table :"#{from}#{it}", :"#{to}#{it}" }
    %w[_pages _acknowledgments].each { rename_column :"#{to}#{it}", :"#{from}_id", :"#{to}_id" }
    # Left with the old prefix: the custom-named indexes rename_table can't derive
    select_rows("SELECT tablename, indexname FROM pg_indexes WHERE indexname LIKE #{quote("index_#{from}%")}")
      .each { |table, index| rename_index table, index, index.sub(from, to) }

    SLUG_COLUMNS.each do |table_column, type|
      table, column = table_column.split(".")
      execute "UPDATE #{table} SET #{column} = replace(#{column}::text, #{quote(from)}, #{quote(to)})::#{type} " \
        "WHERE #{column}::text LIKE #{quote("%#{from}%")}"
    end
    execute "UPDATE organization_features SET name = replace(name, #{quote(from.titleize)}, #{quote(to.titleize)}) " \
      "WHERE name LIKE #{quote("%#{from.titleize}%")}"
    execute "UPDATE active_storage_attachments SET record_type = #{quote("#{to.camelize}Page")} " \
      "WHERE record_type = #{quote("#{from.camelize}Page")}"
    # The key an in-progress registration stores its course and acknowledged pages under. No
    # index covers it, so bound the scan to b_params made since the tables were (2026-06-28)
    execute "UPDATE b_params SET params = (params - #{quote(from)}) || jsonb_build_object(#{quote(to)}, params -> #{quote(from)}) " \
      "WHERE params ? #{quote(from)} AND id > COALESCE((SELECT id FROM b_params WHERE created_at < '2026-06-28' ORDER BY id DESC LIMIT 1), 0)"
  end

  def quote(value) = connection.quote(value)
end
