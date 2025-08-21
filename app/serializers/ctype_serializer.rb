class CtypeSerializer < ApplicationSerializer
  attributes :name,
    :slug,
    :has_multiple

  self.root = "component_types"
end
