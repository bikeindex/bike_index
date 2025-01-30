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
    # Create locales
    create_file(File.join(app_component_dir, "component.yml"),
      translations_hash(I18n.available_locales).to_yaml)

    # Create files in spec/components/
    template("component_spec.rb", File.join(spec_component_dir, "component_spec.rb"))
    template("component_system_spec.rb", File.join(spec_component_dir, "component_system_spec.rb"))
  end

  def create_locale_file
    # I18n.available_locales.each do |locale|
    #   create_file locale_destination(locale), translations_hash([locale]).to_yaml
    # end
    # else
    # create_file(File.join(app_component_dir, "component.yml"), translations_hash(I18n.available_locales).to_yaml)
    # end
  end

  private

  def translations_hash(locales)
    locales.map { |locale| [locale.to_s, translation_keys] }.to_h
  end

  def translation_keys
    keys = attributes.map(&:name)
    keys = %w[hello] if keys.empty?
    keys.map { |name| [name, name.capitalize] }.to_h
  end

  def locale_destination(locale = nil)
    extension = ".#{locale}" if locale
    File.join(app_component_dir, "component.yml")
    # else
    #   File.join(component_path, class_path, "#{file_name}_component#{extension}.yml")
    # end
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
end
