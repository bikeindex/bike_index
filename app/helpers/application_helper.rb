module ApplicationHelper
  # Override ActionView `cache` helper, adding the current locale to the cache
  # key.
  def cache(key = {}, options = {}, &block)
    super([key, locale: I18n.locale], options, &block)
  end

  def notification_delivery_display(status)
    text = if status == "delivery_success"
      check_mark
    elsif status == "delivery_pending"
      "..."
    else
      "failure"
    end
    content_tag(:span, text, title: status&.titleize, style: "cursor:default;")
  end

  def attr_list_item(desc, title)
    return nil unless desc.present?
    content_tag(:li) do
      content_tag(:strong, "#{title}: ", class: "attr-title") +
        content_tag(:span, desc)
    end
  end

  def active_link(link_text, link_path, html_options = {})
    match_controller = html_options.delete(:match_controller)
    html_options[:class] ||= ""
    html_options[:class] += " active" if current_page_active?(link_path, match_controller)
    link_to(raw(link_text), link_path, html_options).html_safe
  end

  def current_page_active?(link_path, match_controller = false)
    if match_controller
      begin
        link_controller = Rails.application.routes.recognize_path(link_path)[:controller]
        Rails.application.routes.recognize_path(request.url)[:controller] == link_controller
      rescue # This mainly fails in testing - but why not rescue always
        false
      end
    else
      current_page?(link_path)
    end
  end

  # Used to render the page wrapper
  # MUST be either:
  #  - a valid partial file in views/shared
  #  - nil - which just calls yield directly
  def current_page_skeleton
    return "organized_skeleton" if controller_namespace == "organized" && action_name != "landing"
    return nil if controller_namespace == "search"
    return nil if @force_landing_page_render
    case controller_name
    when "bikes"
      "edit_bike_skeleton" if %w[update].include?(action_name)
    when "edits", "theft_alerts", "recovery"
      "edit_bike_skeleton"
    when "info"
      "content_skeleton" unless %w[terms security vendor_terms privacy support_the_index].include?(action_name)
    when "welcome"
      "content_skeleton" if %w[goodbye].include?(action_name)
    when "organizations"
      "content_skeleton" if %w[lightspeed_integration].include?(action_name)
    when "news", "feedbacks", "manufacturers", "errors", "registrations"
      "content_skeleton"
    end
  end

  # For determining menu items to display on content skeleton
  def content_page_type
    if controller_name == "info"
      action_name
    elsif controller_name == "news"
      "news"
    end
  end

  def body_class
    if controller_name == "landing_pages" || @force_landing_page_render
      "landing-page-body"
    elsif current_page_skeleton == "organized_skeleton"
      "organized-body"
    end
  end

  def admin_nav_link(link_text, link_path)
    if controller_name == "dashboard"
      if action_name == "invitations" && link_text == "Invitations"
        class_name = "active"
      elsif action_name == "show" && link_text == "Go hard"
        class_name = "active"
      end
    elsif controller_name == "payments"
      if action_name == "invoices" && link_text == "Invoices"
        class_name = "active"
      elsif link_text == "Payments"
        class_name = "active"
      end
    else
      class_name = (controller_name == link_text.downcase.tr(" ", "_")) ? "active" : ""
    end
    (link_to link_text, link_path, class: class_name).html_safe
  end

  def link_to_add_fields(name, f, association, class_name: nil, obj_attrs: {}, filename: nil)
    new_object = f.object.send(association).klass.new(obj_attrs)
    id = new_object.object_id
    filename ||= association.to_s.singularize + "_fields"
    fields = f.fields_for(association, new_object, child_index: id) { |builder|
      render(filename, f: builder)
    }
    link_to name, "#", class: "add_fields #{class_name}",
      data: {id: id, fields: fields.delete("\n")}
  end

  def revised_link_to_add_components(name, f, association)
    new_object = f.object.send(association).klass.new
    id = new_object.object_id
    fields = f.fields_for(association, new_object, child_index: id) { |builder|
      render("/bikes_edit/bike_fields/revised_component_fields", f: builder, ctype_id: Ctype.other.id)
    }
    text = "<span class='context-display-help'>+</span>#{name}"
    link_to(text.html_safe, "#", class: "add_fields", data: {id: id, fields: fields.delete("\n")})
  end

  def listicle_html(list_item)
    c = content_tag(:h2, list_item.title, class: "list-item-title")
    if list_item.image_credits.present?
      c = content_tag(:div, list_item.image_credits_html.html_safe,
        class: "listicle-image-credit") << c
    end
    if list_item.image.present?
      c = image_tag(list_item.image_url(:large)) << c
    end
    c = content_tag :article, c
    c << content_tag(:article, list_item.body_html.html_safe) if list_item.body_html.present?
    c
  end

  def button_to_toggle_task_completion_status(ambassador_task_assignment, current_user, current_organization)
    is_complete = ambassador_task_assignment.completed?
    button_label = is_complete ? "Mark Pending" : "Mark Complete"

    button_to(
      button_label,
      organization_ambassador_task_assignment_url(current_organization, ambassador_task_assignment),
      method: :put,
      params: {completed: !is_complete},
      class: "btn btn-primary"
    )
  end

  def twitterable(user)
    if user.show_twitter && user.twitter
      link_to "Twitter", "https://twitter.com/#{user.twitter}"
    end
  end

  def websiteable(user)
    if user.show_website && user.mb_link_target.present?
      link_to (user.mb_link_title || "Website"), user.mb_link_target
    end
  end

  def instagramable(user)
    if user.show_instagram && user.instagram
      link_to "Instagram", "https://instagram.com/#{user.instagram}"
    end
  end

  # TODO: location refactor - do something more sophisticated
  def address_formatted(obj)
    obj.address
  end

  def show_sharing_links(user)
    [twitterable(user), instagramable(user), websiteable(user)].compact.to_sentence.html_safe
  end

  def pretty_print_json(data, no_blank = false)
    require "coderay"
    cleaned_data = if no_blank
      # Show false values, just not empty or nil things
      data.select do |k, v|
        next unless InputNormalizer.present_or_false?(v)
        [k, v]
      end.compact.to_h
    else
      data
    end
    CodeRay.scan(JSON.pretty_generate(cleaned_data), :json).div.html_safe
  end
end
