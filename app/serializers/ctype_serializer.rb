class CtypeSerializer < ActiveModel::Serializer
  attributes :name,
    :slug,
    :has_multiple

  self.root = "component_types"

end
