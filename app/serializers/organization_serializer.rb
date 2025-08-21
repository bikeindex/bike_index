class OrganizationSerializer < ApplicationSerializer
  attributes :name, :website, :kind, :slug
  has_many :locations
end
