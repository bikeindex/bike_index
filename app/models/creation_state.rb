class CreationState < ActiveRecord::Base
  belongs_to :bike
  belongs_to :organization
  belongs_to :creator, class_name: 'User'

  def self.origins
    %w(embed embed_extended embed_partial api_v1 api_v2).freeze
  end

  def creation_description
    return 'pos' if 'is_pos'
    return 'bulk' if 'is_bulk'
    return origin.humanize.downcase if origin
  end

  before_validation :ensure_permitted_origin
  def ensure_permitted_origin
    self.origin = nil unless self.class.origins.include?(origin)
    true
  end

  after_create :create_bike_organization
  def create_bike_organization
    return true unless organization.present?
    BikeOrganization.where(bike_id: bike_id, organization_id: organization_id).first_or_create
  end

  after_save :set_reflexive_association
  def set_reflexive_association # Just for the time being, to make migration easier
    b = Bike.unscoped.find(bike_id)
    b.update_attribute :creation_state_id, id unless b.creation_state_id == id
  end
end
