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
       recovery_posted tsved_at estimated_value).map(&:to_sym).freeze
 end

  attr_accessor :date_stolen_input

  belongs_to :bike
  has_one :current_bike, class_name: 'Bike', foreign_key: :current_stolen_record_id
  has_one :recovery_display
  belongs_to :country
  belongs_to :state
  belongs_to :creation_organization, class_name: 'Organization'

  validates_presence_of :bike
  validate :date_present
  def date_present
    unless date_stolen.present? || date_stolen_input.present?
      errors.add :base, 'You need to include the date stolen'
    end
  end

  default_scope { where(current: true) }
  scope :approveds, -> { where(approved: true) }
  scope :approveds_with_reports, -> { approveds.where('police_report_number IS NOT NULL').where('police_report_department IS NOT NULL') }
  scope :not_tsved, -> { where('tsved_at IS NULL') }
  scope :tsv_today, -> { where("tsved_at IS NULL OR tsved_at >= '#{Time.now.beginning_of_day}'") }

  scope :recovered, -> { unscoped.where(current: false).order('date_recovered desc') }
  scope :displayable, -> { recovered.where(can_share_recovery: true) }
  scope :recovery_unposted, -> { unscoped.where(current: false, recovery_posted: false) }

  geocoded_by :address
  after_validation :geocode, if: lambda { (self.city.present? || self.zipcode.present?) && self.country.present? }

  def self.revised_date_format
    '%a %b %d %Y'
  end

  def self.revised_date_format_hour
    "#{revised_date_format} %H"
  end

  def self.find_matching_token(bike_id:, recovery_link_token:)
    return nil unless bike_id.present? && recovery_link_token.present?
    unscoped.where(bike_id: bike_id, recovery_link_token: recovery_link_token).first
  end

  before_validation :date_from_date_stolen_input
  def date_from_date_stolen_input
    return true unless date_stolen_input.present?
    self.date_stolen = parse_date_from_input(date_stolen_input)
  end

  def parse_date_from_input(date_string)
    return Time.now unless date_string.present?
    DateTime.strptime("#{date_string} 06", self.class.revised_date_format_hour)
  end

  def recovered?
    !current?
  end

  def formatted_date
    date_stolen && date_stolen.strftime(self.class.revised_date_format)
  end

  def address(skip_default_country: false)
    country_string = country && country.iso
    if skip_default_country
      country_string = nil if country_string == 'US'
    else
      return nil unless country
    end
    [
      street,
      city,
      (state && state.abbreviation),
      zipcode,
      country_string
    ].reject(&:blank?).join(', ')
  end

  def address_short # Doesn't include street
    [city,
     (state && state.abbreviation),
     zipcode].reject(&:blank?).join(',')
  end

  def self.locking_description
    ['U-lock', 'Two U-locks', 'U-lock and cable', 'Chain with padlock',
     'Cable lock', 'Heavy duty bicycle security chain', 'Not locked', 'Other'].freeze
  end

  def self.locking_description_select
    locking_description.map { |l| [l, l] }
  end

  def self.locking_defeat_description
    [
      'Lock was cut, and left at the scene.',
      'Lock was opened, and left unharmed at the scene.',
      'Lock is missing, along with the bike.',
      'Object that bike was locked to was broken, removed, or otherwise compromised.',
      'Other situation, please describe below.',
      'Bike was not locked'
    ]
  end

  def self.locking_defeat_description_select
    locking_defeat_description.map { |l| [l, l] }
  end

  before_save :set_phone, :fix_date, :titleize_city, :update_tsved_at
  def set_phone
    self.phone = Phonifyer.phonify(phone) if phone
    self.secondary_phone = Phonifyer.phonify(secondary_phone) if secondary_phone
  end

  def fix_date
    year = date_stolen.year
    if date_stolen.year < (Time.now - 100.years).year
      decade = year.to_s.chars.last(2).join('')
      corrected = date_stolen.change(year: "20#{decade}".to_i)
      self.date_stolen = corrected
    end
    if date_stolen > Time.now + 2.days
      corrected = date_stolen.change(year: Time.now.year - 1)
      self.date_stolen = corrected
    end
  end

  def titleize_city
    if city.present?
      self.city = city.gsub('USA', '').gsub(/,?(,|\s)[A-Z]+\s?++\z/, '')
      self.city = city.strip.titleize
    end
    true
  end

  def update_tsved_at
    self.tsved_at = nil if police_report_number_changed? || police_report_department_changed?
    true
  end

  def tsv_col(i)
    return '' unless i.present?
    i.gsub(/\\?(\t|\\t)+/i, ' ').gsub(/\\?(\r|\\r)+/i, ' ')
     .gsub(/\\?(\n|\\n)+/i, ' ').gsub(/\\?\\?('|")+/, ' ')
  end

  def tsv_row(with_article = true, with_stolen_locations: false)
    b = bike
    return '' unless b.present?
    row = ''
    if with_stolen_locations
      row << "#{tsv_col(city)}\t#{tsv_col(state && state.abbreviation)}\t"
    end
    row << tsv_col(b.mnfg_name)
    row << "\t"
    row << tsv_col(b.frame_model)
    row << "\t"
    row << tsv_col(b.serial) unless b.serial == 'absent'
    row << "\t"
    row << tsv_col(b.frame_colors.to_sentence)
    row << tsv_col(b.description)
    row << " #{tsv_col(theft_description)}"
    row << " Stolen from: #{tsv_col(address)}"
    row << "\t"
    row << "Article\t" if with_article
    row << date_stolen.strftime('%Y-%m-%d')
    row << "\t"
    row << tsv_col(police_report_number)
    row << "\t"
    row << tsv_col(police_report_department)
    row << "\t\t"
    row << "#{ENV['BASE_URL']}/bikes/#{b.id}\n"
    row
  end

  def add_recovery_information(info = {})
    info = ActiveSupport::HashWithIndifferentAccess.new(info)
    self.date_recovered ||= parse_date_from_input(info[:date_recovered])
    update_attributes(current: false,
                      recovered_description: info[:recovered_description],
                      index_helped_recovery: ("#{info[:index_helped_recovery]}" =~ /t|1/i).present?,
                      can_share_recovery: ("#{info[:can_share_recovery]}" =~ /t|1/i).present?)
    bike.stolen = false
    bike.save
  end

  def find_or_create_recovery_link_token
    return recovery_link_token if recovery_link_token.present?
    begin
      self.recovery_link_token = SecureRandom.urlsafe_base64
    end while self.class.where(recovery_link_token: recovery_link_token).exists?
    save
    recovery_link_token
  end
end
