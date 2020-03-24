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
  # scope :international, where("country_id IS NOT #{Country.united_states.id}")

  before_validation :set_address
  before_save :shown_from_organization
  before_save :set_phone
  after_commit :update_organization

  def shown_from_organization
    self.shown = organization && organization.allowed_show
    true
  end

  def set_phone
    self.phone = Phonifyer.phonify(self.phone) if self.phone
  end

  def set_address
    self.address =
      if country.blank?
        ""
      else
        [
          street,
          city,
          state.present? ? state.abbreviation : nil,
          zipcode,
          country.name,
        ].reject(&:blank?).join(", ")
      end
  end

  def org_location_id
    "#{self.organization_id}_#{self.id}"
  end

  def update_organization
    # Because we need to update the organization and make sure it is shown on
    # the map correctly, manually update to ensure that it runs save callbacks
    organization&.reload&.update_attributes(updated_at: Time.current)
  end

  def display_name
    return "" if organization.blank?
    return name if name == organization.name

    "#{organization.name} - #{name}"
  end
end
