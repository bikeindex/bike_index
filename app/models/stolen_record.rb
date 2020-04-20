class StolenRecord < ApplicationRecord
  include ActiveModel::Dirty
  include Phonifyerable
  include Geocodeable

  RECOVERY_DISPLAY_STATUS_ENUM = {
    not_eligible: 0,
    waiting_on_decision: 1,
    displayable_no_photo: 2,
    displayed: 3,
    not_displayed: 4,
  }.freeze

  attr_accessor :timezone # Just to provide a backup and permit assignment

  def self.old_attr_accessible
    # recovery_tweet, recovery_share # We edit this in the admin panel
    %w(police_report_number police_report_department locking_description lock_defeat_description
       timezone date_stolen bike creation_organization_id country_id state_id street zipcode city latitude
       longitude theft_description current phone secondary_phone phone_for_everyone
       phone_for_users phone_for_shops phone_for_police receive_notifications proof_of_ownership
       approved recovered_at recovered_description index_helped_recovery can_share_recovery
       recovery_posted tsved_at estimated_value).map(&:to_sym).freeze
  end

  belongs_to :bike
  has_one :current_bike, class_name: "Bike", foreign_key: :current_stolen_record_id
  has_one :recovery_display
  belongs_to :country
  belongs_to :state
  belongs_to :creation_organization, class_name: "Organization"
  belongs_to :recovering_user, class_name: "User"
  has_many :theft_alerts
  has_one :alert_image

  validates_presence_of :bike
  validates_presence_of :date_stolen

  enum recovery_display_status: RECOVERY_DISPLAY_STATUS_ENUM

  default_scope { where(current: true) }
  scope :approveds, -> { where(approved: true) }
  scope :approveds_with_reports, -> { approveds.where("police_report_number IS NOT NULL").where("police_report_department IS NOT NULL") }
  scope :not_tsved, -> { where("tsved_at IS NULL") }
  scope :tsv_today, -> { where("tsved_at IS NULL OR tsved_at >= '#{Time.current.beginning_of_day}'") }

  scope :recovered, -> { unscoped.where(current: false) }
  scope :recovered_ordered, -> { recovered.order("recovered_at desc") }
  scope :displayable, -> { recovered_ordered.where(can_share_recovery: true) }
  scope :recovery_unposted, -> { unscoped.where(current: false, recovery_posted: false) }
  scope :missing_location, -> { where(street: ["", nil]) }

  before_save :set_calculated_attributes
  after_validation :reverse_geocode, unless: :skip_geocoding?
  after_save :remove_outdated_alert_images
  after_commit :update_associations

  reverse_geocoded_by :latitude, :longitude do |stolen_record, results|
    if (geo = results.first)
      stolen_record.country ||= Country.find_by(name: geo.country)
      stolen_record.city ||= geo.city
      stolen_record.state ||= State.find_by(abbreviation: geo.state_code)
      stolen_record.neighborhood ||= geo.neighborhood
    end
  end

  def twitter_accounts_in_proximity
    [
      TwitterAccount.default_account_for_country(country),
      TwitterAccount.active.near(self, 50),
    ].flatten.compact.uniq
  end

  def self.recovery_display_statuses; RECOVERY_DISPLAY_STATUS_ENUM.keys.map(&:to_s) end

  def self.find_matching_token(bike_id:, recovery_link_token:)
    return nil unless bike_id.present? && recovery_link_token.present?
    unscoped.where(bike_id: bike_id, recovery_link_token: recovery_link_token).first
  end

  def self.recovering_user_recording_start; Time.at(1558821440) end # Rough time that PR#790 was merged

  def recovered?; !current? end

  # TODO: check based on the ownership of the bike at the time of recovery
  def recovering_user_owner?; recovering_user.present? && bike&.owner == recovering_user end

  def pre_recovering_user?; recovered_at.present? && recovered_at < self.class.recovering_user_recording_start end

  # Only display if they have put in an address - so that we don't show on initial creation
  def display_checklist?; address.present? end

  def missing_location?; street.blank? end

  def address(skip_default_country: false, force_show_address: false)
    Geocodeable.address(
      self,
      street: (force_show_address || show_address),
      country: [(:skip_default if skip_default_country)]
    ).presence
  end

  # The stolen bike's general location (city and state / city and country if non-US)
  # Include all available components (city, state, country) unconditionally if
  # `include_all` is passed.
  def address_location(include_all: false)
    city_and_state =
      [city&.titleize, state&.abbreviation&.upcase].reject(&:blank?).join(", ")

    if include_all.present?
      [city_and_state, country&.iso].reject(&:blank?).join(" - ")
    elsif state.present?
      city_and_state
    elsif country.present?
      [city&.titleize, country&.iso].reject(&:blank?).join(" - ")
    end
  end

  LOCKING_DESCRIPTIONS = [
    "U-lock",
    "Two U-locks",
    "U-lock and cable",
    "Chain with padlock",
    "Cable lock",
    "Heavy duty bicycle security chain",
    "Not locked",
    "Other",
  ].freeze

  def self.locking_description
    LOCKING_DESCRIPTIONS
  end

  def self.locking_description_select_options
    normalize = ->(value) { value.to_s.downcase.gsub(/[^[:alnum:]]+/, "_") }
    translation_scope = [:activerecord, :select_options, self.name.underscore]

    locking_description.map do |name|
      localized_name = I18n.t(normalize.call(name), scope: translation_scope)
      [localized_name, name]
    end
  end

  LOCKING_DEFEAT_DESCRIPTIONS = [
    "Lock was cut, and left at the scene",
    "Lock was opened, and left unharmed at the scene",
    "Lock is missing, along with the bike",
    "Object that bike was locked to was broken, removed, or otherwise compromised",
    "Other situation, please describe below",
    "Bike was not locked",
  ].freeze

  def self.locking_defeat_description
    LOCKING_DEFEAT_DESCRIPTIONS
  end

  def self.locking_defeat_description_select_options
    normalize = ->(value) { value.to_s.downcase.gsub(/[^[:alnum:]]+/, "_") }
    translation_scope = [:activerecord, :select_options, self.name.underscore]

    locking_defeat_description.map do |name|
      localized_name = I18n.t(normalize.call(name), scope: translation_scope)
      [localized_name, name]
    end
  end

  def set_calculated_attributes
    set_phone
    fix_date
    self.street = nil unless street.present? # Make it easier to find blank addresses
    titleize_city
    update_tsved_at
    self.recovery_display_status = calculated_recovery_display_status
  end

  def set_phone
    self.phone = Phonifyer.phonify(phone) if phone
    self.secondary_phone = Phonifyer.phonify(secondary_phone) if secondary_phone
  end

  def fix_date
    year = date_stolen.year
    if date_stolen.year < (Time.current - 100.years).year
      decade = year.to_s.chars.last(2).join("")
      corrected = date_stolen.change(year: "20#{decade}".to_i)
      self.date_stolen = corrected
    end
    if date_stolen > Time.current + 2.days
      corrected = date_stolen.change(year: Time.current.year - 1)
      self.date_stolen = corrected
    end
  end

  def titleize_city
    if city.present?
      self.city = city.gsub("USA", "").gsub(/,?(,|\s)[A-Z]+\s?++\z/, "")
      self.city = city.strip.titleize
    end
    true
  end

  def update_tsved_at
    self.tsved_at = nil if police_report_number_changed? || police_report_department_changed?
    true
  end

  def tsv_col(i)
    return "" unless i.present?
    i.gsub(/\\?(\t|\\t)+/i, " ").gsub(/\\?(\r|\\r)+/i, " ")
     .gsub(/\\?(\n|\\n)+/i, " ").gsub(/\\?\\?('|")+/, " ")
  end

  def tsv_row(with_article = true, with_stolen_locations: false)
    b = bike
    return "" unless b.present?
    row = ""
    if with_stolen_locations
      row << "#{tsv_col(city)}\t#{tsv_col(state && state.abbreviation)}\t"
    end
    row << tsv_col(b.mnfg_name)
    row << "\t"
    row << tsv_col(b.frame_model)
    row << "\t"
    row << tsv_col(b.serial_display)
    row << "\t"
    row << tsv_col(b.frame_colors.to_sentence)
    row << tsv_col(b.description)
    row << " #{tsv_col(theft_description)}"
    row << " Stolen from: #{tsv_col(address)}"
    row << "\t"
    row << "Article\t" if with_article
    row << date_stolen.strftime("%Y-%m-%d")
    row << "\t"
    row << tsv_col(police_report_number)
    row << "\t"
    row << tsv_col(police_report_department)
    row << "\t\t"
    row << "#{ENV["BASE_URL"]}/bikes/#{b.id}\n"
    row
  end

  def calculated_recovery_display_status
    return "not_eligible" unless can_share_recovery
    return "not_displayed" if not_displayed?
    return "displayed" if recovery_display.present?
    if bike&.thumb_path&.present?
      "waiting_on_decision"
    else
      "displayable_no_photo"
    end
  end

  def add_recovery_information(info = {})
    info = ActiveSupport::HashWithIndifferentAccess.new(info)
    self.recovered_at = TimeParser.parse(info[:recovered_at], info[:timezone]) || Time.current

    update_attributes(
      current: false,
      recovered_description: info[:recovered_description],
      recovering_user_id: info[:recovering_user_id],
      index_helped_recovery: ("#{info[:index_helped_recovery]}" =~ /t|1/i).present?,
      can_share_recovery: ("#{info[:can_share_recovery]}" =~ /t|1/i).present?,
    )

    bike.stolen = false
    bike.save.tap { |was_saved| notify_of_promoted_alert_recovery if was_saved }
  end

  def find_or_create_recovery_link_token
    return recovery_link_token if recovery_link_token.present?
    update_attributes(recovery_link_token: SecurityTokenizer.new_token)
    recovery_link_token
  end

  # The associated bike's first public image, if available. Else nil.
  def bike_main_image
    bike&.public_images&.order(:id)&.first
  end

  def current_alert_image
    alert_image || generate_alert_image
  end

  # Generate the "promoted alert image"
  # (One of the stolen bike's public images, placed on a branded template)
  #
  # The URL is available immediately - processing is performed in the background.
  # bike_image: [PublicImage]
  def generate_alert_image(bike_image: bike_main_image)
    return if bike_image&.image.blank?

    alert_image&.destroy
    new_image = AlertImage.create(image: bike_image.image, stolen_record: self)

    if new_image.valid?
      new_image
    else
      update(alert_image: nil)
      nil
    end
  end

  # If the bike has been recovered, remove the alert_image
  def remove_outdated_alert_images
    if bike.blank? || !bike.stolen?
      alert_image&.destroy
      reload
    end
  end

  def update_associations
    return true unless bike.present?
    # Bump bike only if it looks like this is bike's current_stolen_record
    if current
      bike.update_attributes(current_stolen_record: self, manual_csr: true)
    end
    bike.user&.update_attributes(updated_at: Time.current)
  end

  def notify_of_promoted_alert_recovery
    return unless recovered? && theft_alerts.active.present?

    EmailTheftAlertNotificationWorker
      .perform_async(theft_alerts.active.last.id, :recovered)
  end
end
