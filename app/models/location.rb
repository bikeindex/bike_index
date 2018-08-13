class Location < ActiveRecord::Base
  acts_as_paranoid
  belongs_to :organization # Locations are organization locations
  belongs_to :country
  belongs_to :state
  validates_presence_of :name, :organization_id, :city, :country_id
  has_many :bikes

  scope :by_state, -> { order(:state_id) }
  scope :shown, -> { where(shown: true) }
  # scope :international, where("country_id IS NOT #{Country.united_states.id}")

  before_save :shown_from_organization
  before_save :set_phone
  after_commit :update_organization

  unless Rails.env.test?
    geocoded_by :address
    after_validation :geocode
  end

  def shown_from_organization
    self.shown = organization && organization.allowed_show
    true
  end

  def address
    return nil unless self.country
    [
      street,
      city,
      state.present? ? state.abbreviation : nil,
      zipcode, 
      country.name
    ].compact.reject(&:blank?).join(", ")
  end

  def set_phone
    self.phone = Phonifyer.phonify(self.phone) if self.phone
  end

  def org_location_id
    "#{self.organization_id}_#{self.id}"
  end

  def update_organization
    # Because we need to update the organization and make sure it is shown on the map correctly
    # Manually update to ensure that it runs the before save stuff
    organization && organization.update_attributes(updated_at: Time.now)
  end

  def display_name
    if name == organization.name
      name
    else
      "#{organization.name} - #{name}"
    end
  end
end
