class ComponentSerializer < ActiveModel::Serializer
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
end
