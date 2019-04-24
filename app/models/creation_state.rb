class CreationState < ActiveRecord::Base
  belongs_to :bike
  belongs_to :organization
  belongs_to :creator, class_name: "User"
  belongs_to :bulk_import

  POS_KIND_ENUM = {
    not_pos: 0,
    other_pos: 1,
    lightspeed_pos: 2,
    ascend_pos: 3,
  }.freeze

  enum pos_kind: POS_KIND_ENUM

  before_validation :set_calculated_attributes
  after_create :create_bike_organization
  after_save :set_reflexive_association

  def self.origins
    %w[embed embed_extended embed_partial api_v1 api_v2 bulk_import_worker].freeze
  end

  def creation_description
    if is_pos
      pos_kind.gsub("_pos", "").humanize
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
    BikeOrganization.where(bike_id: bike_id, organization_id: organization_id).first_or_create
    if organization.parent_organization.present?
      BikeOrganization.where(bike_id: bike_id, organization_id: organization.parent_organization_id).first_or_create
    end
    true # Legacy concerns, so excited for TODO: Rails 5 update
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
      "not_pos"
    end
  end
end
