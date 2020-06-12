class Location < ApplicationRecord
  include Geocodeable

  acts_as_paranoid
  belongs_to :organization, inverse_of: :locations # Locations are organization locations
  belongs_to :country
  belongs_to :state
  has_many :bikes

  validates :name, :city, :country, :organization, presence: true

  scope :by_state, -> { order(:state_id) }
  scope :shown, -> { where(shown: true) }
  scope :publicly_visible, -> { shown.where(not_publicly_visible: false) }
  scope :impound_locations, -> { where(impound_location: true) }
  scope :default_impound_locations, -> { impound_locations.where(default_impound_location: true) }
  # scope :international, where("country_id IS NOT #{Country.united_states.id}")

  before_save :set_calculated_attributes
  after_commit :update_associations

  attr_accessor :skip_update

  def other_organization_locations; Location.where(organization_id: organization_id).where.not(id: id) end

  def address; Geocodeable.address(self, country: %i[name]) end

  def org_location_id; "#{self.organization_id}_#{self.id}" end

  def publicly_visible; !not_publicly_visible end

  def publicly_visible=(val); self.not_publicly_visible = !ParamsNormalizer.boolean(val) end

  def set_calculated_attributes
    self.phone = Phonifyer.phonify(self.phone)
    self.shown = calculated_shown
  end

  def update_associations
    return true if skip_update
    # If this wasn't set by the organization callback (which uses skip_update: true)
    # And this location was updated with default_impound_location, ensure there aren't any others
    if default_impound_location
      other_organization_locations.update_all(default_impound_location: false)
    end
    # Because we need to update the organization and make sure it is shown on
    # the map correctly, manually update to ensure that it runs save callbacks
    organization&.reload&.update(updated_at: Time.current, skip_update: true)
  end

  def display_name
    return "" if organization.blank?
    name == organization.name ? name : "#{organization.name} - #{name}"
  end

  private

  def calculated_shown
    return false if not_publicly_visible
    organization.present? && organization.allowed_show?
  end
end
