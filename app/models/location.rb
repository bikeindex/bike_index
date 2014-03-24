class Location < ActiveRecord::Base
  attr_accessible :name,
    :organization_id,
    :organization,
    :zipcode,
    :city,
    :state_id,
    :country_id,
    :street,
    :phone,
    :email,
    :latitude,
    :longitude,
    :shown


  acts_as_paranoid
  belongs_to :organization
  belongs_to :country
  belongs_to :state
  validates_presence_of :name, :organization_id, :city, :country_id
  has_many :bikes

  scope :by_state, order(:state_id)
  scope :shown, where(shown: true)
  # scope :international, where("country_id IS NOT #{Country.find_by_iso("US").id}")

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

  before_save :set_shown
  def set_shown
    self.shown = true if organization.show_on_map
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
