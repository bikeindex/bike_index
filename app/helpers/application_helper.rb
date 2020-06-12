module ApplicationHelper
  # Override ActionView `cache` helper, adding the current locale to the cache
  # key.
  def cache(key = {}, options = {}, &block)
    super([key, locale: I18n.locale], options, &block)
  end

  def check_mark
    "&#x2713;".html_safe
  end

  def cross_mark
    "&#x274C;".html_safe
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
        return false
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
    return nil if @force_landing_page_render
    case controller_name
    when "bikes"
      "edit_bike_skeleton" if %w(edit update).include?(action_name)
    when "info"
      "content_skeleton" unless %w(terms vendor_terms privacy support_the_index).include?(action_name)
    when "welcome"
      "content_skeleton" if %w(goodbye).include?(action_name)
    when "organizations"
      "content_skeleton" if %w(lightspeed_integration).include?(action_name)
    when *%w(news feedbacks manufacturers errors registrations)
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
      if action_name == "invoices"
        class_name = "active" if link_text == "Invoices"
      else
        class_name = "active" if link_text == "Payments"
      end
    else
      class_name = controller_name == link_text.downcase.gsub(" ", "_") ? "active" : ""
    end
    (link_to link_text, link_path, class: class_name).html_safe
  end

  def link_to_add_fields(name, f, association, class_name: nil, obj_attrs: {}, filename: nil)
    new_object = f.object.send(association).klass.new(obj_attrs)
    id = new_object.object_id
    filename ||= association.to_s.singularize + '_fields'
    fields = f.fields_for(association, new_object, child_index: id) do |builder|
      render(filename, f: builder)
    end
    link_to name, '#', class: "add_fields #{class_name}",
                       data: { id: id, fields: fields.delete("\n") }
  end

  def revised_link_to_add_components(name, f, association)
    new_object = f.object.send(association).klass.new
    id = new_object.object_id
    fields = f.fields_for(association, new_object, child_index: id) do |builder|
      render("/bikes/bike_fields/revised_component_fields", f: builder, ctype_id: Ctype.other.id)
    end
    text = "<span class='context-display-help'>+</span>#{name}"
    link_to(text.html_safe, "#", class: "add_fields", data: { id: id, fields: fields.gsub("\n", "") })
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

  def sortable(column, title = nil, html_options = {})
    title ||= column.gsub(/_(id|at)\z/, "").titleize
    html_options[:class] = "#{html_options[:class]} sortable-link"
    direction = column == sort_column && sort_direction == "desc" ? "asc" : "desc"
    if column == sort_column
      html_options[:class] += " active"
      span_content = direction == "asc" ? "\u2193" : "\u2191"
    end
    link_to(sortable_search_params.merge(sort: column, direction: direction, query: params[:query]), html_options) do
      concat(title.html_safe)
      concat(content_tag(:span, span_content, class: "sortable-direction"))
    end
  end

  def sortable_search_params?
    sortable_search_params.values.reject(&:blank?).any?
  end

  def sortable_search_params
    search_param_keys = params.keys.select { |k| k.to_s.match(/\Asearch_/) }
    params.permit(:direction, :sort, :user_id, :organization_id, :period, :start_time, :end_time, :query, :render_chart, *search_param_keys)
  end

  def button_to_toggle_task_completion_status(ambassador_task_assignment, current_user, current_organization)
    is_complete = ambassador_task_assignment.completed?
    button_label = is_complete ? "Mark Pending" : "Mark Complete"

    button_to(
      button_label,
      organization_ambassador_task_assignment_url(current_organization, ambassador_task_assignment),
      method: :put,
      params: { completed: !is_complete },
      class: "btn btn-primary",
    )
  end

  def phone_display(str)
    return "" if str.blank?
    phone_components = Phonifyer.components(str)
    number_to_phone(phone_components[:number], phone_components.except(:number))
  end

  def phone_link(phone, html_options = {})
    return "" if phone.blank?
    # Switch extension to be pause, remove whitespace
    phone_url = Phonifyer.phonify(phone).gsub("x", ";").gsub(/\s+/, "")
    link_to(phone_display(phone), "tel:#{phone_url}", html_options)
  end

  def twitterable(user)
    if user.show_twitter and user.twitter
      link_to "Twitter", "https://twitter.com/#{user.twitter}"
    end
  end

  # TODO: location refactor - do something more sophisticated
  def address_formatted(obj)
    obj.address
  end

  def websiteable(user)
    if user.show_website and user.website
      link_to "Website", user.website
    end
  end

  def show_twitter_and_website(user)
    if twitterable(user) or websiteable(user)
      html = ""
      if twitterable(user)
        html << twitterable(user)
        html << " and #{websiteable(user)}" if websiteable(user)
      else
        html << websiteable(user)
      end
      html.html_safe
    end
  end

  def pretty_print_json(data)
    require "coderay"
    CodeRay.scan(JSON.pretty_generate(data), :json).div.html_safe
  end

  def bike_placeholder_image_path
    image_path("revised/bike_photo_placeholder.svg")
  end

  # Return the canonical url for the given blog post.
  # If none available, default to the bike index url, removing any query params
  # (e.g. the locale param).
  def canonical_url(blog)
    url = blog.canonical_url.presence || news_url(blog)
    url.split("?").first
  end
end
