class StolenRecord < ActiveRecord::Base
  attr_accessible :police_report_number,
    :police_report_department,
    :locking_description,
    :lock_defeat_description,
    :date_stolen,
    :bike,
    :country_id,
    :street,
    :zipcode,
    :city,
    :state,
    :latitude,
    :longitude,
    :theft_description,
    :current,
    :phone,
    :phone_for_everyone,
    :phone_for_users,
    :phone_for_shops,
    :phone_for_police

  belongs_to :bike
  belongs_to :country

  validates_presence_of :bike, :date_stolen

  default_scope where(current: true)

  def address
    return nil unless self.country
    [street, city, state, zipcode, country.name].compact.join(', ')
  end

  unless Rails.env.test?
    geocoded_by :address
    after_validation :geocode, :if => lambda { self.street.present? && self.city.present? && self.country.present? }
  end

  def self.locking_description_select
    lds = ["U-lock", "Two U-locks", "U-lock and cable", "Chain with padlock",
      "Cable lock", "Heavy duty bicycle security chain", "Not locked", "Other"]
    select_params = []
    lds.each do |l|
      select_params << [l,l]
    end
    select_params
  end

  def self.lock_defeat_description_select
    ldds = [
      "Lock was cut, and left at the scene.",
      "Lock was opened, and left unharmed at the scene.",
      "Lock is missing, along with the bike.",
      "Object that bike was locked to was broken, removed, or otherwise compromised.",
      "Other situation, please describe below.",
      "Bike was not locked"
    ]
    select_params = []
    ldds.each do |l|
      select_params << [l,l]
    end
    select_params
  end

  before_save :set_phone
  def set_phone
    self.phone = Phonifyer.phonify(self.phone) if self.phone 
  end


end
