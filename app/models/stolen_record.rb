class StolenRecord < ActiveRecord::Base
  include ActiveModel::Dirty
  include Phonifyerable
  def self.old_attr_accessible
    # recovery_share, # We edit this in the admin panel
    # recovery_tweet, # We edit this in the admin panel
    # date_stolen_input # now putting this in here, on revised, because less stupid
    %w(police_report_number police_report_department locking_description lock_defeat_description
       date_stolen date_stolen_input bike creation_organization_id country_id state_id street zipcode city latitude
       longitude theft_description current phone secondary_phone phone_for_everyone
       phone_for_users phone_for_shops phone_for_police receive_notifications proof_of_ownership
       approved date_recovered recovered_description index_helped_recovery can_share_recovery
       recovery_posted tsved_at).map(&:to_sym).freeze
 end

  attr_accessor :date_stolen_input

  belongs_to :bike
  has_one :current_bike, class_name: 'Bike', foreign_key: :current_stolen_record_id
  has_one :recovery_display
  belongs_to :country
  belongs_to :state
  belongs_to :creation_organization, class_name: "Organization"

  validates_presence_of :bike
  validate :date_present
  def date_present
    unless date_stolen.present? || date_stolen_input.present?
      errors.add :base, 'You need to include the date stolen'
    end
  end

  default_scope { where(current: true) }
  scope :approveds, -> { where(approved: true) }
  scope :approveds_with_reports, -> { approveds.where("police_report_number IS NOT NULL").
    where("police_report_department IS NOT NULL") }
  scope :not_tsved, -> { where("tsved_at IS NULL") }
  scope :tsv_today, -> { where("tsved_at IS NULL OR tsved_at >= '#{Time.now.beginning_of_day}'") }

  scope :recovered, -> { unscoped.where(current: false).order("date_recovered desc") }
  scope :displayable, -> { unscoped.where(current: false, can_share_recovery: true).order("date_recovered desc") }
  scope :recovery_unposted, -> { unscoped.where(
    current: false,
    recovery_posted: false
  )}

  def self.revised_date_format
    '%a %b %d %Y'
  end

  def self.revised_date_format_hour
    "#{revised_date_format} %H"
  end

  before_validation :date_from_date_stolen_input
  def date_from_date_stolen_input
    if date_stolen_input.present?
      self.date_stolen = DateTime.strptime("#{date_stolen_input} 06", self.class.revised_date_format_hour)
    else
      true
    end
  end

  def formatted_date
    date_stolen && date_stolen.strftime(self.class.revised_date_format)
  end

  def address
    return nil unless self.country
    a = []
    a << street if street.present?
    a << city
    a << state.abbreviation if state.present?
    (a+[zipcode, country.name]).compact.join(', ')
  end

  def address_short # Doesn't include street
    [
      city,
      (state && state.abbreviation),
      zipcode,
    ].reject(&:blank?).join(',')
  end

  def show_stolen_address
    [
      street,
      city,
      (state && state.abbreviation),
      zipcode,
      (country && country.iso unless country.iso == 'US')
    ].reject(&:blank?).join(', ')
  end

  # unless Rails.env.test?
    geocoded_by :address
    after_validation :geocode, if: lambda { (self.city.present? || self.zipcode.present?) && self.country.present? }
  # end

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

  before_save :set_phone, :fix_date, :titleize_city, :update_tsved_at
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

  def update_tsved_at
    self.tsved_at = nil if police_report_number_changed? || police_report_department_changed?
    true
  end

  def tsv_col(i)
    col = ""
    col << i.gsub(/\\?(\t|\\t)+/i, ' ').gsub(/\\?(\r|\\r)+/i,' ').gsub(/\\?(\n|\\n)+/i,' ').gsub(/\\?\\?('|")+/,' ') if i.present?
    col
  end

  def tsv_row(with_article=true)
    b = self.bike
    return '' unless b.present?
    row = ""
    row << tsv_col(b.manufacturer_name)
    row << "\t"
    row << tsv_col(b.frame_model)
    row << "\t"
    row << tsv_col(b.serial) unless b.serial == 'absent'
    row << "\t"
    row << tsv_col(b.frame_colors.to_sentence)
    row << tsv_col(b.description)
    row << " #{tsv_col(self.theft_description)}"
    row << " Stolen from: #{tsv_col(self.address)}"
    row << "\t"
    row << "Article\t" if with_article
    row << self.date_stolen.strftime("%Y-%m-%d")
    row << "\t"
    row << tsv_col(self.police_report_number)
    row << "\t"
    row << tsv_col(self.police_report_department)
    row << "\t\t"
    row << "#{ENV['BASE_URL']}/bikes/#{b.id}\n"
    row
  end

  def add_recovery_information(info)
    bike.update_attribute :stolen, false if bike.stolen
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
