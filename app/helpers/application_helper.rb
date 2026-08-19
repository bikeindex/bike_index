module ApplicationHelper
  include Binxtils::NavHelper
  include Binxtils::SortableHelper

  # Every layout's <body>. UI::ActiveLink's controller matching reads the route off the page
  # rather than off the link, since the link's markup is a fragment cache shared by every page,
  # and a layout that opens its own <body> and forgets it fails silently -- the link just never
  # goes current. The route isn't page_id, which controllers override to borrow another page's
  # styles.
  def body_tag(html_class: nil, **html_options, &block)
    tag.body(id: page_id, class: html_class.presence || body_class, **html_options,
      data: {page_route: "#{controller_path}##{action_name}"}, &block)
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

  # Organized lays out its own general alert, and takes over the body background
  def main_content_organized?
    PageBlock::MainContent::Wrapper::Component.kind(
      controller_namespace:,
      controller_name:,
      action_name:,
      force_landing_page_render: @force_landing_page_render,
      register_flow_organization_id: @register_flow_organization_id
    ) == :organized
  end

  # Set by going back to the embed form, cleared by taking the register flow's link the
  # other way - the organized menu follows it
  def old_register_view?
    session[:old_register_view].present?
  end

  # Its opening step, then every step after it on /register
  def register_flow_page?
    controller_name == "register" || (controller_name == "registrations" && action_name == "new")
  end

  # Deprecated - UI::Forms::NestedFields::Component replaces this. Every set this adds shares one
  # child_index, so clicking twice submits a single record
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

  def show_sharing_links(user)
    [twitterable(user), instagramable(user), websiteable(user)].compact.to_sentence.html_safe
  end

  def pretty_print_json(data, no_blank = false)
    require "coderay"
    cleaned_data = if no_blank
      # Show false values, just not empty or nil things
      data.select do |k, v|
        next unless Binxtils::InputNormalizer.present_or_false?(v)

        [k, v]
      end.compact.to_h
    else
      data
    end
    CodeRay.scan(JSON.pretty_generate(cleaned_data), :json).div.html_safe
  end

  private

  def body_class
    if controller_name == "landing_pages" || @force_landing_page_render
      if %w[for_schools for_law_enforcement].include?(action_name)
        "kelsey_landing-page-body"
      else
        "landing-page-body"
      end
    elsif controller_name == "info" && action_name == "resources"
      "kelsey_landing-page-body"
    elsif main_content_organized?
      # Register::Page's gray only covers the form, and the organized container insets it -
      # so the page paints it instead, behind the whole content column
      register_flow_page? ? "organized-body tw:bg-gray-100 tw:dark:bg-gray-900" : "organized-body"
    elsif controller_name == "registrations" && action_name == "show"
      "tw:bg-[#f7f6fb]"
    end
  end
end
