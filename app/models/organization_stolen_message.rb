class OrganizationStolenMessage < ApplicationRecord
  MAX_body_LENGTH = 300
  KIND_ENUM = {area: 0, association: 1}

  belongs_to :organization
  has_many :stolen_records

  validates :organization_id, presence: true, uniqueness: true

  before_validation :set_calculated_attributes

  enum kind: KIND_ENUM

  scope :enabled, -> { where(is_enabled: true) }
  scope :disabled, -> { where(is_enabled: false) }

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.for(organization)
    OrganizationStolenMessage.where(organization_id: organization.id).first_or_create
  end

  def self.for_coordinates(latitude, longitude)
    # area.
    # Geocoder::Calculations.bounding_box([to_coordinates], search_radius_miles)
  end

  def self.clean_body(str)
    return nil if str.blank?
    ActionController::Base.helpers.strip_tags(str).gsub("&amp;", "&")
      .strip.gsub(/\s+/, " ").truncate(MAX_body_LENGTH, omission: "")
  end

  def self.default_kind_for_organization_kind(org_kind)
    %w[law_enforcement bike_advocacy].include?(org_kind) ? "area" : "association"
  end

  def disabled?
    !is_enabled?
  end

  def set_calculated_attributes
    self.body = self.class.clean_body(body)
    self.latitude = organization&.location_latitude
    self.longitude = organization&.location_longitude
    self.radius_miles ||= organization.search_radius_miles
    self.kind ||= self.class.default_kind_for_organization_kind(organization&.kind)
    self.is_enabled = false unless can_enable?
  end

  private

  def can_enable?
    return false if body.blank?
    return true if association?
    latitude.present? && longitude.present? && radius_miles.present?
  end
end
