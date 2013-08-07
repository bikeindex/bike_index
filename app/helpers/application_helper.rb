module ApplicationHelper

  def titleation
    title = "Bike Index"
    title = "#{@title} - #{title}" if @title.present?
    return title
  end
  
  def nav_link(link_text, link_path)
    class_name = current_page?(link_path) ? 'active' : ''
    class_name = "active" if controller_name == "blogs" && link_path == blogs_url
    html = link_to raw(link_text), link_path, class: class_name
    return html.html_safe
  end

  def admin_nav_link(link_text, link_path)
    if controller_name == "dashboard" 
      if action_name == "invitations" && link_text == "Invitations"
        class_name = "active"
      elsif action_name == "show" && link_text == "Go hard"
        class_name = "active"
      end
    elsif controller_name == "organization_invitations" && link_text == "Invitations"
      class_name = "active"
    elsif controller_name == "bike_token_invitations" && link_text == "Invitations"
      class_name = "active"
    else
      class_name = controller_name == link_text.downcase ? 'active' : ''
    end

    html = link_to link_text, link_path, class: class_name
    return html.html_safe
  end

  def content_nav_class(section)
    "active-menu" if section == @active_section
  end

  def link_to_add_fields(name, f, association)
    new_object = f.object.send(association).klass.new
    id = new_object.object_id
    fields = f.fields_for(association, new_object, child_index: id) do |builder|
      render(association.to_s.singularize + "_fields", f: builder)
    end
    link_to(name, '#', class: "add_fields button-blue", data: {id: id, fields: fields.gsub("\n", "")})
  end

  def link_to_add_components(name, f, association, component_scope)
    new_object = f.object.send(association).klass.new
    id = new_object.object_id
    fields = f.fields_for(association, new_object, child_index: id) do |builder|
      render("/bikes/bike_fields/component_fields", f: builder, component_group: component_scope)
    end
    link_to(name, '#', class: "add_fields button-blue", data: {id: id, fields: fields.gsub("\n", "")})
  end

end
