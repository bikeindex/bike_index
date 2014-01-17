class ComponentsCreatorError < StandardError
end

class ComponentCreator
  def initialize(creation_params = {})
    @bike = creation_params[:bike]
    @b_param = creation_params[:b_param]
  end

  def set_manufacturer_key(component)
    if component[:manufacturer]
      m_name = component[:manufacturer]
      manufacturer = Manufacturer.fuzzy_name_find(m_name)
      unless manufacturer.present?
        manufacturer = Manufacturer.find_by_name("Other")
        component[:manufacturer_other] = m_name.titleize if m_name.present?
      end
      component[:manufacturer_id] = manufacturer.id if manufacturer.present?
      component.delete(:manufacturer)
    end
    component
  end

  def set_component_type(component)
    ctype_slug = component[:component_type]
    return component unless ctype_slug.present?
    ctype = Ctype.find_by_slug(ctype_slug.downcase.strip)
    component[:ctype_id] = ctype.id 
    component.delete(:component_type)
    component
  end

  def set_duplicate(component)
    position = component[:front_or_rear]
    component.delete([:front_or_rear])
    components = [component]
    if position.present?
      position = position.downcase.strip
      if position == "front"
        components[0][:front] = true
      elsif position == "rear"
        components[0][:rear] = true
      elsif position == "both"
        components << component
        components[0][:front] = true
        components[1][:rear] = true
      end
    end
    components
  end

  def create_component(component)
    components = set_duplicate(component)
    components.each { |c| c[:bike_id] = @bike.id }
    components.each { |c| Component.create(c) }
  end

  def create_components_from_params
    if @b_param.present? && @b_param.params.present? && @b_param.params[:components].present?
      c_length = (0...@b_param.params[:components].count).to_a
      c_length.each do |c_number|
        if @b_param.params[:components].kind_of?(Array)
          component = @b_param.params[:components][c_number]
        else
          component = @b_param.params[:components][c_number.to_s]
        end
        component = set_manufacturer_key(component)
        component = set_component_type(component)
        create_component(component)
      end
    end
  end

end