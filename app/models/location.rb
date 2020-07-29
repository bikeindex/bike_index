class Location < ApplicationRecord
  include Geocodeable

  acts_as_paranoid

  belongs_to :organization, inverse_of: :locations # Locations are organization locations
  belongs_to :country
  belongs_to :state

  has_many :bikes
  has_one :appointment_configuration
  has_many :appointments

  validates :name, :city, :country, :organization, presence: true

  scope :by_state, -> { order(:state_id) }
  scope :shown, -> { where(shown: true) }
  scope :publicly_visible, -> { shown.where(not_publicly_visible: false) }
  scope :impound_locations, -> { where(impound_location: true) }
  scope :default_impound_locations, -> { impound_locations.where(default_impound_location: true) }
  # scope :international, where("country_id IS NOT #{Country.united_states.id}")

  before_save :set_calculated_attributes
  after_commit :update_associations
  before_destroy :ensure_destroy_permitted!

  attr_accessor :skip_update

  # For now, doesn't do anything - but eventually we may switch to slugged locations, so prep for it
  def self.friendly_find(str)
    find_by_id(str)
  end

  def other_organization_locations
    Location.where(organization_id: organization_id).where.not(id: id)
  end

  def address
    Geocodeable.address(self, country: %i[name])
  end

  def org_location_id
    "#{organization_id}_#{id}"
  end

  def publicly_visible
    !not_publicly_visible
  end

  def virtual_line_on?
    appointment_configuration.present? && appointment_configuration.virtual_line_on?
  end

  # may also block if it's had appointments
  def destroy_forbidden?
    virtual_line_on?
  end

  def publicly_visible=(val)
    self.not_publicly_visible = !ParamsNormalizer.boolean(val)
  end

  def set_calculated_attributes
    self.phone = Phonifyer.phonify(phone)
    self.shown = calculated_shown
  end

  def last_recent_appointment_in_line
    return nil unless virtual_line_on?
    appointments.in_line.last || appointments.appointment_update_ordered.recently_updated.last
  end

  def last_line_number
    last_recent_appointment_in_line&.line_number
  end

  def next_line_number
    return nil unless virtual_line_on?
    (last_line_number || 0) + 1
  end

  def update_associations
    return true if skip_update
    # If this wasn't set by the organization callback (which uses skip_update: true)
    # And this location was updated with default_impound_location, ensure there aren't any others
    if default_impound_location
      # Updating columns, no need to skip_update
      other_organization_locations.update_all(default_impound_location: false)
    end
    # Because we need to update the organization and make sure it is shown on
    # the map correctly, manually update to ensure that it runs save callbacks
    organization&.reload&.update(updated_at: Time.current)
    # Just in case this changed something here
    LocationAppointmentsQueueWorker.perform_async(id)
  end

  def display_name
    return "" if organization.blank?
    name == organization.name ? name : "#{organization.name} - #{name}"
  end

  # Quick and dirty hack to ensure it's blocked - frontend should prevent doing this normally
  def ensure_destroy_permitted!
    return true unless destroy_forbidden?
    raise StandardError, "Can't destroy a location with appointments enabled"
  end

  private

  def calculated_shown
    return false if not_publicly_visible
    organization.present? && organization.allowed_show?
  end
end
