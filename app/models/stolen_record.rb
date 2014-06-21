class StolenRecord < ActiveRecord::Base
  attr_accessible :police_report_number,
    :police_report_department,
    :locking_description,
    :lock_defeat_description,
    :date_stolen,
    :bike,
    :creation_organization_id,
    :country_id,
    :state_id,
    :street,
    :zipcode,
    :city,
    :latitude,
    :longitude,
    :theft_description,
    :current,
    :phone,
    :secondary_phone,
    :phone_for_everyone,
    :phone_for_users,
    :phone_for_shops,
    :phone_for_police,
    :receive_notifications,
    :approved
    
  belongs_to :bike
  belongs_to :country
  belongs_to :state
  belongs_to :creation_organization, class_name: "Organization"

  validates_presence_of :bike, :date_stolen

  default_scope where(current: true)

  def address
    return nil unless self.country
    a = []
    a << street if street.present?
    a << city
    a << state.abbreviation if state.present?
    (a+[zipcode, country.name]).compact.join(', ')
  end

  unless Rails.env.test?
    geocoded_by :address
    after_validation :geocode, if: lambda { self.city.present? && self.country.present? }
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
    self.secondary_phone = Phonifyer.phonify(self.secondary_phone) if self.secondary_phone 
  end

  def tsv_col(i)
    col = ""
    col << i.gsub(/\\?\\t/i, ' ').gsub(/\\?\\r/i,' ').gsub(/\\?\\n/i,' ').gsub(/\\?\\?'|"/,' ') if i.present?
    col
  end

  def tsv_row
    b = self.bike 
    return '' unless b.present?
    row = ""
    row << tsv_col(b.manufacturer_name)
    row << "\t"
    row << tsv_col(b.frame_model)
    row << "\t"
    row << tsv_col(b.serial_number) unless b.serial_number == 'absent'
    row << "\t"
    row << tsv_col(b.frame_colors.to_sentence)
    row << tsv_col(b.description)
    row << " #{tsv_col(self.theft_description)}"
    row << " Stolen from: #{tsv_col(self.address)}"
    row << "\t"
    row << "Article\t"
    row << self.date_stolen.strftime("%Y-%m-%d-")
    row << "\t"
    row << tsv_col(self.police_report_number)
    row << "\t"
    row << tsv_col(self.police_report_department)
    row << "\t\t"
    row << "https://bikeindex.org/bikes/#{b.id}\n"
    row
  end

end
