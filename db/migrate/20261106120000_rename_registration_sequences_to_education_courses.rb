class RenameRegistrationSequencesToEducationCourses < ActiveRecord::Migration[8.1]
  # Index names rename_table can't derive from the table name
  CUSTOM_INDEXES = {
    "s" => %w[one_active_per_org one_active_template one_draft_per_org one_draft_template],
    "_acknowledgments" => %w[one_per_b_param pending]
  }.freeze

  def up = rename_everything(from: "registration_sequence", to: "education_course")

  def down = rename_everything(from: "education_course", to: "registration_sequence")

  private

  def rename_everything(from:, to:)
    %w[s _pages _acknowledgments].each { rename_table :"#{from}#{it}", :"#{to}#{it}" }
    %w[_pages _acknowledgments].each { rename_column :"#{to}#{it}", :"#{from}_id", :"#{to}_id" }
    CUSTOM_INDEXES.each do |table, suffixes|
      suffixes.each { rename_index :"#{to}#{table}", "index_#{from}#{table}_#{it}", "index_#{to}#{table}_#{it}" }
    end

    rename_feature_slugs({"#{from}s" => "#{to}s", "#{from}s_edit" => "#{to}s_edit"})
    execute "UPDATE organization_features SET name = replace(name, #{quote(from.titleize)}, #{quote(to.titleize)})"
    execute "UPDATE active_storage_attachments SET record_type = #{quote("#{to.camelize}Page")} " \
      "WHERE record_type = #{quote("#{from.camelize}Page")}"
    # The key an in-progress registration stores its course and acknowledged pages under
    execute "UPDATE b_params SET params = (params - #{quote(from)}) || " \
      "jsonb_build_object(#{quote(to)}, params -> #{quote(from)}) WHERE params ? #{quote(from)}"
  end

  def rename_feature_slugs(slugs)
    old_slugs = "array[#{slugs.keys.map { quote(it) }.join(", ")}]"
    cases = slugs.map { |old_slug, new_slug| "WHEN #{quote(old_slug)} THEN #{quote(new_slug)}" }.join(" ")

    %w[organizations.enabled_feature_slugs invoices.child_enabled_feature_slugs].each do |table_column|
      table, column = table_column.split(".")
      execute <<~SQL
        UPDATE #{table} SET #{column} = (
          SELECT jsonb_agg(CASE slug #{cases} ELSE slug END ORDER BY position)
          FROM jsonb_array_elements_text(#{column}) WITH ORDINALITY AS elements(slug, position))
        WHERE jsonb_typeof(#{column}) = 'array' AND #{column} ?| #{old_slugs}
      SQL
    end

    replaced = slugs.reduce("feature_slugs") { |sql, (old_slug, new_slug)| "array_replace(#{sql}, #{quote(old_slug)}, #{quote(new_slug)})" }
    execute "UPDATE organization_features SET feature_slugs = #{replaced} WHERE feature_slugs && #{old_slugs}::text[]"
  end

  def quote(value) = connection.quote(value)
end
