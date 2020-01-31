class CreationState < ApplicationRecord
  belongs_to :bike
  belongs_to :organization
  belongs_to :creator, class_name: "User"
  belongs_to :bulk_import

  enum state: Bike::STATE_ENUM
  enum pos_kind: Organization::POS_KIND_ENUM

  before_validation :set_calculated_attributes
  after_create :create_bike_organization
  after_save :set_reflexive_association

  attr_accessor :can_edit_claimed

  def self.origins
    %w[embed embed_extended embed_partial api_v1 api_v2 bulk_import_worker organization_form].freeze
  end

  def creation_description
    if is_pos
      pos_kind.to_s.gsub("_pos", "").humanize
    elsif is_bulk
      "bulk reg"
    elsif origin.present?
      origin.humanize.downcase
    end
  end

  def set_calculated_attributes
    self.origin = nil unless self.class.origins.include?(origin)
    self.pos_kind = calculated_pos_kind
  end

  def create_bike_organization
    return true unless organization.present?
    unless BikeOrganization.where(bike_id: bike_id, organization_id: organization_id).present?
      BikeOrganization.create(bike_id: bike_id, organization_id: organization_id, can_edit_claimed: can_edit_claimed)
    end
    if organization.parent_organization.present? && BikeOrganization.where(bike_id: bike_id, organization_id: organization.parent_organization_id).blank?
      BikeOrganization.create(bike_id: bike_id, organization_id: organization.parent_organization_id, can_edit_claimed: can_edit_claimed)
    end
  end

  def set_reflexive_association
    # Just for the time being, to make migration easier
    b = Bike.unscoped.where(id: bike_id).first
    b.update_attribute(:creation_state_id, id) if b.present? && b&.creation_state_id != id
    true
  end

  private

  def calculated_pos_kind
    if bulk_import&.ascend?
      self.is_pos = true # Lazy hack, could be improved
      "ascend_pos"
    elsif is_pos
      "lightspeed_pos"
    else
      "no_pos"
    end
  end
end
