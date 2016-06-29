class Location < ActiveRecord::Base
  def self.old_attr_accessible
    %w(name organization_id organization zipcode city state_id
       country_id street phone email latitude longitude shown).map(&:to_sym).freeze
  end  
  acts_as_paranoid
  belongs_to :organization
  belongs_to :country
  belongs_to :state
  validates_presence_of :name, :organization_id, :city, :country_id
  has_many :bikes

  scope :by_state, -> { order(:state_id) }
  scope :shown, -> { where(shown: true) }
  # scope :international, where("country_id IS NOT #{Country.united_states.id}")

  before_save :shown_from_organization
  def shown_from_organization
    self.shown = organization && organization.allowed_show
    true
  end

  def address
    return nil unless self.country
    a = []
    a << street
    a << city
    a << state.abbreviation if state.present?
    (a+[zipcode, country.name]).compact.join(', ')
  end

  unless Rails.env.test?
    geocoded_by :address
    after_validation :geocode
  end

  before_save :set_phone
  def set_phone
    self.phone = Phonifyer.phonify(self.phone) if self.phone
  end

  def org_location_id
    "#{self.organization_id}_#{self.id}"
  end

  def display_name
    if name == organization.name
      name
    else
      "#{organization.name} - #{name}"
    end
  end

end
