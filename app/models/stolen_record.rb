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
    :proof_of_ownership,
    :approved,
    :date_recovered,
    :recovered_description,
    :index_helped_recovery,
    :can_share_recovery,
    :recovery_share, # We edit this in the admin panel
    :recovery_tweet, # We edit this in the admin panel
    :recovery_posted
    
  belongs_to :bike
  has_one :current_bike, class_name: 'Bike', foreign_key: :current_stolen_record_id
  belongs_to :country
  belongs_to :state
  belongs_to :creation_organization, class_name: "Organization"

  validates_presence_of :bike, :date_stolen

  default_scope where(current: true)

  scope :recovered, unscoped.where(current: false).order("date_recovered desc")
  scope :recovery_unposted, unscoped.where(
    current: false,
    recovery_posted: false
  )

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

  def self.locking_description
    ["U-lock", "Two U-locks", "U-lock and cable", "Chain with padlock",
      "Cable lock", "Heavy duty bicycle security chain", "Not locked", "Other"]
  end
  def self.locking_description_select
    lds = locking_description
    select_params = []
    lds.each do |l|
      select_params << [l,l]
    end
    select_params
  end

  def self.locking_defeat_description
    [
      "Lock was cut, and left at the scene.",
      "Lock was opened, and left unharmed at the scene.",
      "Lock is missing, along with the bike.",
      "Object that bike was locked to was broken, removed, or otherwise compromised.",
      "Other situation, please describe below.",
      "Bike was not locked"
    ]
  end
  def self.locking_defeat_description_select
    ldds = locking_defeat_description
    select_params = []
    ldds.each do |l|
      select_params << [l,l]
    end
    select_params
  end

  before_save :set_phone, :fix_date, :titleize_city
  def set_phone
    self.phone = Phonifyer.phonify(self.phone) if self.phone 
    self.secondary_phone = Phonifyer.phonify(self.secondary_phone) if self.secondary_phone 
  end

  def fix_date
    year = date_stolen.year
    if date_stolen.year < (Time.now - 100.years).year
      decade = year.to_s.chars.last(2).join('')
      corrected = date_stolen.change({year: "20#{decade}".to_i })
      self.date_stolen = corrected
    end
    if date_stolen > Time.now
      corrected = date_stolen.change({year: Time.now.year - 1 })
      self.date_stolen = corrected
    end
  end

  def titleize_city
    if city.present?
      self.city = city.gsub('USA','').gsub(/,?(,|\s)[A-Z]+\s?++\z/,'')
      self.city = city.strip.titleize
    end
    true
  end

  def tsv_col(i)
    col = ""
    col << i.gsub(/\\?(\t|\\t)+/i, ' ').gsub(/\\?(\r|\\r)+/i,' ').gsub(/\\?(\n|\\n)+/i,' ').gsub(/\\?\\?('|")+/,' ') if i.present?
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
    row << self.date_stolen.strftime("%Y-%m-%d")
    row << "\t"
    row << tsv_col(self.police_report_number)
    row << "\t"
    row << tsv_col(self.police_report_department)
    row << "\t\t"
    row << "https://bikeindex.org/bikes/#{b.id}\n"
    row
  end

  def add_recovery_information(info)
    self.date_recovered = Time.now
    self.recovered_description = info[:request_reason]
    self.current = false
    if info[:index_helped_recovery].present?
      if info[:index_helped_recovery].to_s.match(/t|1/i)
        self.index_helped_recovery = true
      end
    end
    if info[:can_share_recovery].present?
      if info[:can_share_recovery].to_s.match(/t|1/i)
        self.can_share_recovery = true
      end
    end
  end

end
