module HeaderTagHelper
  def header_tags_component_options
    organization_name = current_organization&.short_name
    page_title = @page_title || page_title_for_edit_bikes(controller_name, action_name)

    {
      page_title:,
      page_obj: @page_obj || @blog || @bike || @user,
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

  def page_title_for_edit_bikes(controller_name, action_name)
    return unless %w[bikes bike_versions].include?(controller_name)
    return unless action_name == "edit" || action_name == "update" || @edit_templates.present?

    if @edit_templates.present?
      # Some of the theft alert templates don't have translations, so just jam it in there
      template_str = @edit_templates[@edit_template] || @edit_template&.humanize
      "#{template_str} - #{@bike.title_string}"
    else
      bike_obj = @bike || @bike_version
      "Edit #{bike_obj&.title_string}"
    end
  end
end
