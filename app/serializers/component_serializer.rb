class ComponentSerializer < ApplicationSerializer
  attributes :id,
    :description,
    :serial_number,
    :component_type,
    :component_group,
    :rear,
    :front,
    :manufacturer_name,
    :model_name,
    :year

  def model_name
    object.component_model
  end

  def manufacturer_name
    object.mnfg_name
  end
end
