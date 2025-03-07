module HeaderTagHelper
  def header_tags_component_options
    organization_name = current_organization&.short_name
    translation_key = translation_key_for(controller_name, action_name)
    page_title = @page_title || page_title_for_edit_bikes(controller_name, action_name) ||
      translation_if_exists("meta_titles.#{translation_key}", organization_name)
    page_description = translation_if_exists("meta_descriptions.#{translation_key}", organization_name)

    {
      page_title:,
      page_description:,
      page_obj: @page_obj || @blog || @bike,
      updated_at: @page_updated_at,
      organization_name:,
      controller_name:,
      controller_namespace:,
      action_name:,
      request_url: request.url,
      language: I18n.locale
    }
  end

  private

  # Add tests for:
  # - page title & description for welcome choose_registration
  # - page title & description for bikes new stolen
  # - page title for bikes edit
  # - page title for bike_versions edit
  # - page title for bikes edit

  def page_title_for_edit_bikes(controller_name, action_name)
    return unless %w[bikes bike_versions].include?(controller_name)
    return unless action_name == "edit" || action_name == "update" || @edit_templates.present?

    if @edit_templates.present?
      # Some of the theft alert templates don't have translations, so just jam it in there
      template_str = @edit_templates[@edit_template] || @edit_template&.humanize
      "#{template_str} - #{@bike.title_string}"
    else
      "Edit #{@bike.title_string}"
    end
  end

  def translation_if_exists(key, organization_name)
    I18n.exists?(key) ? t(key, organization: organization_name) : nil
  end

  def translation_key_for(controller_name, action_name)
    return "bikes_new" if controller_name == "welcome" && action_name == "choose_registration"

    if %w[bikes bike_versions].include?(controller_name)
      return "bikes_new_stolen" if (action_name == "new" || action_name == "create") && @bike.status_stolen?
    end

    "#{controller_name}_#{action_name}"
  end
end
