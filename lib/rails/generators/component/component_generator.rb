# frozen_string_literal: true

# Based on https://github.com/github/view_component/blob/master/lib/rails/generators/component/component_generator.rb

class ComponentGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  argument :attributes, type: :array, default: [], banner: "attribute"
  check_class_collision suffix: "Component"

  class_option :inline, type: :boolean, default: false
  class_option :locale, type: :boolean, default: true

  def create_component
    # Create files in app/components/
    template("component.rb", File.join(app_component_dir, "component.rb"))
    template("component.html.erb", File.join(app_component_dir, "component.html.erb"))
    template("component_controller.js", stimulus_controller_path)
    template("preview.rb", File.join(app_component_dir, "component_preview.rb"))
    # Only generate english locale, the others are handled by translation.io
    create_locale_file(:en)

    # Create tests in spec/components/
    template("component_spec.rb", File.join(spec_component_dir, "component_spec.rb"))
    template("component_system_spec.rb", File.join(spec_component_dir, "component_system_spec.rb"))
  end

  private

  def parent_class
    ApplicationComponent
  end

  def preview_parent_class
    ApplicationComponentPreview
  end

  def initialize_signature
    return if attributes.blank?

    attributes.map { |attr| "#{attr.name}:" }.join(", ")
  end

  def initialize_body
    attributes.map { |attr| "@#{attr.name} = #{attr.name}" }.join("\n    ")
  end

  def initialize_call_method_for_inline?
    options["inline"]
  end

  def component_class
    "#{class_name}::Component"
  end

  def stimulus_controller_path
    File.join(app_component_dir, "component_controller.js")
  end

  def stimulus_controller
    component_class.underscore.split("/").join("--").tr("_", "-")
  end

  def app_component_dir
    File.join("app", "components", component_dir)
  end

  def spec_component_dir
    File.join("spec", "components", component_dir)
  end

  def component_dir
    File.join(class_path, file_name)
  end

  def preview_path
    "/rails/view_components/#{component_dir}/component/default"
  end

  def create_locale_file(locale)
    create_file(
      File.join(app_component_dir, "component.#{locale}.yml"),
      translation_hash(locale).to_yaml
    )
  end

  def translation_hash(locale)
    translation_scope_array = [locale.to_s, "components"] + class_name.underscore.downcase.split("/")

    translation_scope_array.reverse.inject(translation_keys) { |hash, key| {key => hash} }
  end

  def translation_keys
    keys = attributes.any? ? attributes.map(&:name) : []
    keys.map { |name| [name, name.capitalize] }.to_h
  end
end
