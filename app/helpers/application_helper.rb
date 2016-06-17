module ApplicationHelper
  def active_link(link_text, link_path, match_controller: false, class_name: '', id: '')
    class_name += ' active' if current_page_active(link_path, match_controller: match_controller)
    link_to(raw(link_text), link_path, class: class_name, id: id).html_safe
  end

  def current_page_active(link_path, match_controller: false)
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
    return 'organized_skeleton' if sub_module_name == 'organized_'
    case controller_name
    when 'bikes'
      'edit_bike_skeleton' if %w(edit update).include?(action_name)
    when 'info'
      'content_skeleton' unless %w(terms vendor_terms privacy support_the_index).include?(action_name)
    when 'welcome'
      'content_skeleton' if %w(goodbye).include?(action_name)
    when 'organizations'
      'content_skeleton' if %w(new lightspeed_integration).include?(action_name)
    when 'user'
      'content_skeleton' if %w(edit).include?(action_name)
    when 'news', 'feedbacks', 'manufacturers', 'stolen', 'errors'
      'content_skeleton'
    end
  end

  # For determining menu items to display on content skeleton
  def content_page_type
    if controller_name == 'info'
      action_name
    elsif controller_name == 'news'
      'news'
    end
  end

  def current_link(link_text, link_path, class: '') # Revised layout link
    class_name = current_page?(link_path) ? 'active' : ''
    class_name = 'active' if link_path.match(news_index_path) && controller_name == 'news'
    (link_to raw(link_text), link_path, class: class_name).html_safe
  end

  def admin_nav_link(link_text, link_path)
    if controller_name == 'dashboard'
      if action_name == 'invitations' && link_text == 'Invitations'
        class_name = 'active'
      elsif action_name == 'show' && link_text == 'Go hard'
        class_name = 'active'
      end
    elsif controller_name == 'organization_invitations' && link_text == 'Invitations'
      class_name = 'active'
    else
      class_name = controller_name == link_text.downcase.gsub(' ', '_') ? 'active' : ''
    end
    (link_to link_text, link_path, class: class_name).html_safe
  end

  def content_nav_class(section)
    'active-menu' if section == @active_section
  end

  def link_to_add_fields(name, f, association)
    new_object = f.object.send(association).klass.new
    id = new_object.object_id
    fields = f.fields_for(association, new_object, child_index: id) do |builder|
      render(association.to_s.singularize + '_fields', f: builder)
    end
    link_to(name, '#', class: 'add_fields button-blue', data: { id: id, fields: fields.gsub("\n", '') })
  end

  def revised_link_to_add_fields(name, f, association, class_name: nil)
    new_object = f.object.send(association).klass.new
    id = new_object.object_id
    fields = f.fields_for(association, new_object, child_index: id) do |builder|
      render(association.to_s.singularize + '_fields', f: builder)
    end
    link_to(name, '#', class: "add_fields #{class_name}", data: { id: id, fields: fields.gsub("\n", '') })
  end

  def link_to_add_components(name, f, association, component_scope)
    new_object = f.object.send(association).klass.new
    id = new_object.object_id
    fields = f.fields_for(association, new_object, child_index: id) do |builder|
      render('/bikes/bike_fields/component_fields', f: builder, component_group: component_scope)
    end
    link_to(name, '#', class: 'add_fields button-blue', data: { id: id, fields: fields.gsub("\n", '') })
  end

  def revised_link_to_add_components(name, f, association)
    new_object = f.object.send(association).klass.new
    id = new_object.object_id
    fields = f.fields_for(association, new_object, child_index: id) do |builder|
      render('/bikes/bike_fields/revised_component_fields', f: builder, ctype_id: Ctype.unknown.id)
    end
    text = "<span class='context-display-help'>+</span>#{name}"
    link_to(text.html_safe, '#', class: 'add_fields', data: { id: id, fields: fields.gsub("\n", '') })
  end

  def listicle_html(list_item)
    c = content_tag(:h2, list_item.title, class: 'list-item-title')
    if list_item.image_credits.present?
      c = content_tag(:div, list_item.image_credits_html.html_safe,
        class: 'listicle-image-credit') << c
    end
    if list_item.image.present?
      c = image_tag(list_item.image_url(:large)) << c
    end
    c = content_tag :article, c
    c << content_tag(:article, list_item.body_html.html_safe) if list_item.body_html.present?
    c
  end

  # For application_revised.js init scoping
  def body_id
    "#{sub_module_name}#{controller_name}_#{action_name}"
  end

  def sub_module_name
    controller.class.parent.name == 'Object' ? '' : "#{controller.class.parent.name.downcase}_"
  end
end
