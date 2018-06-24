class CreationState < ActiveRecord::Base
  VALID_ORIGINS = %i(embed embed_extended embed_partial api_v1 api_v2 api_v3 csv_importer).freeze
  belongs_to :bike
  belongs_to :organization
  belongs_to :creator, class_name: "User"

  enum origin: VALID_ORIGINS

  def self.origins; VALID_ORIGINS.map(&:to_s) end

  def origin=(val) # ignore invalid origins
    return nil unless self.class.origins.include?(val.downcase)
    super(val)
  end

  def creation_description
    return "pos" if is_pos
    return "bulk reg" if is_bulk
    return "#{origin.humanize.downcase}" if origin
  end

  def set_origin_from_origin_string!
    update_attribute :origin, origin_string
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
