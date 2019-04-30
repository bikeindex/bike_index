class ComponentsCreatorError < StandardError
end

class ComponentCreator
  def initialize(creation_params = {})
    @bike = creation_params[:bike]
    @b_param = creation_params[:b_param]
  end

  def set_component_type(component)
    name = component[:component_type]
    return component unless name.present?
    ctype = Ctype.friendly_find(name)
    if ctype.present?
      component[:ctype_id] = ctype.id
    else
      component[:ctype_id] = Ctype.unknown.id
      component[:ctype_other] = name
    end
    component.delete :component_type
    component
  end

  def component_type_hash(component)
    {}
  end

  def manufacturer_hash(component)
    mnfg_input = component[:manufacturer_id] || component[:manufacturer]
    return {} unless mnfg_input.present?
    manufacturer = Manufacturer.friendly_find(mnfg_input)
    unless manufacturer.present?
      return { manufacturer_id: Manufacturer.other.id, manufacturer_other: mnfg_input }
    end
    { manufacturer_id: manufacturer.id }
  end

  def whitelist_attributes(component)
    comp_attributes = {
      cmodel_name: component[:model_name] || component[:model],
      description: component[:description],
      year: component[:year],
      serial_number: component[:serial_number] || component[:serial],
      front: component[:front],
      rear: component[:rear],
      front_or_rear: component[:front_or_rear],
      ctype_id: component[:ctype_id],
      ctype_other: component[:ctype_other],
      mnfg_name: component[:manufacturer_name] || component[:manufacturer_name] || component[:mnfg_name],
    }.merge(manufacturer_hash(component)).merge(component_type_hash(component))
    comp_attributes.select { |k, v| v.present? }
  end

  def create_component(component)
    Component.create(whitelist_attributes(component).merge(bike_id: @bike.id))
  end

  def update_components_from_params
    @b_param["components"].each_with_index do |comp, index|
      if comp["id"].present?
        component = @bike.components.find(comp["id"])
        (component.destroy && next) if comp["destroy"] || comp["_destroy"] == "1"
      else
        component = @bike.components.new
      end
      comp = set_component_type(comp)
      component.update_attributes whitelist_attributes(comp.with_indifferent_access)
    end
  end

  def create_components_from_params
    if @b_param.present? && @b_param.params.present? && @b_param.params["components"].present?
      (0...@b_param.params["components"].count).to_a.each do |c_number|
        if @b_param.params["components"].kind_of?(Array)
          component = @b_param.params["components"][c_number].with_indifferent_access
        else
          component = @b_param.params["components"][c_number.to_s].with_indifferent_access
        end
        component = set_manufacturer_key(component)
        component = set_component_type(component)
        create_component(component)
      end
    end
  end
end
