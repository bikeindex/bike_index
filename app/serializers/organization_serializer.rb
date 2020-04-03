class OrganizationSerializer < ApplicationSerializer
  attributes :name, :website, :kind
  has_many :locations
end
