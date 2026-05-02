class OrganizationSerializer < ApplicationSerializer
  attributes :name, :short_name, :website, :kind, :slug
  has_many :locations
end
