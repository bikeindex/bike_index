class OrganizationSerializer < ApplicationSerializer
  attributes :name, :short_name, :website, :kind, :slug, :logo_url
  has_many :locations

  def logo_url
    object.avatar_url if object.avatar?
  end
end
