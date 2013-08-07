class OrganizationSerializer < ActiveModel::Serializer
  attributes :name, :slug, :url
  has_many :locations
  
end
