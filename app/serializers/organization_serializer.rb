class OrganizationSerializer < ActiveModel::Serializer
  attributes :name, :website, :kind
  has_many :locations
end
