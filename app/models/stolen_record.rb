# == Schema Information
#
# Table name: stolen_records
#
#  id                             :integer          not null, primary key
#  approved                       :boolean          default(FALSE), not null
#  can_share_recovery             :boolean          default(FALSE), not null
#  city                           :string(255)
#  create_open311                 :boolean          default(FALSE), not null
#  current                        :boolean          default(TRUE)
#  date_stolen                    :datetime
#  estimated_value                :integer
#  index_helped_recovery          :boolean          default(FALSE), not null
#  latitude                       :float
#  lock_defeat_description        :string(255)
#  locking_description            :string(255)
#  longitude                      :float
#  neighborhood                   :string
#  no_notify                      :boolean          default(FALSE)
#  phone                          :string(255)
#  phone_for_everyone             :boolean
#  phone_for_police               :boolean          default(TRUE)
#  phone_for_shops                :boolean          default(TRUE)
#  phone_for_users                :boolean          default(TRUE)
#  police_report_department       :string(255)
#  police_report_number           :string(255)
#  proof_of_ownership             :boolean
#  receive_notifications          :boolean          default(TRUE)
#  recovered_at                   :datetime
#  recovered_description          :text
#  recovery_display_status        :integer          default("not_eligible")
#  recovery_link_token            :text
#  recovery_posted                :boolean          default(FALSE)
#  recovery_share                 :text
#  recovery_tweet                 :text
#  secondary_phone                :string(255)
#  street                         :string(255)
#  theft_description              :text
#  tsved_at                       :datetime
#  zipcode                        :string(255)
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  bike_id                        :integer
#  country_id                     :integer
#  creation_organization_id       :integer
#  organization_stolen_message_id :bigint
#  recovering_user_id             :integer
#  state_id                       :integer
#
# Indexes
#
#  index_stolen_records_on_bike_id                         (bike_id)
#  index_stolen_records_on_latitude_and_longitude          (latitude,longitude)
#  index_stolen_records_on_organization_stolen_message_id  (organization_stolen_message_id)
#  index_stolen_records_on_recovering_user_id              (recovering_user_id)
#
class StolenRecord < ApplicationRecord
  include ActiveModel::Dirty
  include Geocodeable

  RECOVERY_DISPLAY_STATUS_ENUM = {
    not_eligible: 0,
    waiting_on_decision: 1,
    displayable_no_photo: 2,
    recovery_displayed: 3,
    not_displayed: 4
  }.freeze

  LOCKING_DESCRIPTIONS = [
    "U-lock",
    "Two U-locks",
    "U-lock and cable",
    "Chain with padlock",
    "Cable lock",
    "Heavy duty bicycle security chain",
    "Not locked",
    "Other"
  ].freeze

  LOCKING_DEFEAT_DESCRIPTIONS = [
    "Lock was cut, and left at the scene",
    "Lock was opened, and left unharmed at the scene",
    "Lock is missing, along with the bike",
    "Object that bike was locked to was broken, removed, or otherwise compromised",
    "Other situation, please describe below",
    "Bike was not locked"
  ].freeze

  belongs_to :bike
  belongs_to :creation_organization, class_name: "Organization"
  belongs_to :recovering_user, class_name: "User"
  belongs_to :organization_stolen_message

  has_many :impound_claims
  has_many :tweets
  has_many :promoted_alerts
  has_many :notifications, as: :notifiable
  has_many :theft_surveys, -> { theft_survey }, as: :notifiable, class_name: "Notification"
  has_one :alert_image
  has_one :recovery_display
  has_one :current_bike, class_name: "Bike", foreign_key: :current_stolen_record_id

  validates_presence_of :date_stolen

  enum :recovery_display_status, RECOVERY_DISPLAY_STATUS_ENUM

  before_save :set_calculated_attributes
  after_commit :update_associations

  default_scope { current }
  scope :current, -> { where(current: true) }
  scope :unapproved, -> { where(approved: false).joins(:bike).where.not(bikes: {id: nil}) } # Make sure bike isn't deleted
  scope :approveds, -> { where(approved: true) }
  scope :current_and_not, -> { unscoped } # might exclude certain things in the future. Also feels better than calling unscoped everywhere
  scope :approveds_with_reports, -> { approveds.where("police_report_number IS NOT NULL").where("police_report_department IS NOT NULL") }
  scope :not_tsved, -> { where("tsved_at IS NULL") }
  scope :tsv_today, -> { where("tsved_at IS NULL OR tsved_at >= '#{Time.current.beginning_of_day}'") }
  scope :not_spam, -> { left_joins(:bike).where.not(bikes: {likely_spam: true}) }

  scope :recovered, -> { unscoped.where(current: false) }
  scope :recovered_ordered, -> { recovered.order("recovered_at desc") }
  scope :with_promoted_alerts, -> { includes(:promoted_alerts).where.not(promoted_alerts: {id: nil}) }
  scope :can_share_recovery, -> { recovered_ordered.where(can_share_recovery: true) }
  scope :with_recovery_display, -> { joins(:recovery_display).where.not(recovery_displays: {id: nil}) }
  scope :without_recovery_display, -> { left_joins(:recovery_display).where(recovery_displays: {id: nil}) }
  scope :without_location, -> { without_street } # References geocodeable without_street, we need to reconcile this

  attr_accessor :timezone, :skip_update # timezone provides a backup and permits assignment

  class << self
    def recovery_display_statuses
      RECOVERY_DISPLAY_STATUS_ENUM.keys.map(&:to_s)
    end

    def find_matching_token(bike_id:, recovery_link_token:)
      return nil unless bike_id.present? && recovery_link_token.present?
      unscoped.where(bike_id: bike_id, recovery_link_token: recovery_link_token).first
    end

    # Rough time that PR#790 was merged
    def recovering_user_recording_start
      Time.at(1558821440)
    end

    def locking_description
      LOCKING_DESCRIPTIONS
    end

    def locking_description_select_options
      # TODO: normalize with slugifyer, not this random thing
      normalize = ->(value) { value.to_s.downcase.gsub(/[^[:alnum:]]+/, "_") }
      translation_scope = [:activerecord, :select_options, name.underscore]

      locking_description.map do |name|
        localized_name = I18n.t(normalize.call(name), scope: translation_scope)
        [localized_name, name]
      end
    end

    def locking_defeat_description
      LOCKING_DEFEAT_DESCRIPTIONS
    end

    def locking_defeat_description_select_options
      # TODO: normalize with slugifyer, not this random thing
      normalize = ->(value) { value.to_s.downcase.gsub(/[^[:alnum:]]+/, "_") }
      translation_scope = [:activerecord, :select_options, name.underscore]

      locking_defeat_description.map do |name|
        localized_name = I18n.t(normalize.call(name), scope: translation_scope)
        [localized_name, name]
      end
    end

    def corrected_date_stolen(date = nil)
      date = TimeParser.parse(date) || Time.current
      year = date.year
      if year < (Time.current - 100.years).year
        decade = year.to_s[-2..].chars.join("")
        corrected = date.change(year: "20#{decade}".to_i)
        date = corrected
      end
      if date > Time.current + 2.days
        corrected = date.change(year: Time.current.year - 1)
        date = corrected
      end
      date
    end
  end

  # override to enable reverse geocoding if applicable
  def should_be_geocoded?
    !skip_geocoding?
  end

  # Override to add reverse geocoding functionality
  def bike_index_geocode
    if address_changed?
      self.attributes = if address_present?
        GeocodeHelper.coordinates_for(address)
      else
        {latitude: nil, longitude: nil}
      end
    end
    # Try to fill in missing attributes by reverse geocoding
    return if latitude.blank? || longitude.blank? || all_location_attributes_present?
    geohelper_attrs = GeocodeHelper.assignable_address_hash_for(latitude: latitude, longitude: longitude)
    attrs_to_assign = geohelper_attrs.keys.reject { |gattr| self[gattr].present? }
    self.attributes = geohelper_attrs.slice(*attrs_to_assign)
  end

  def recovered?
    !current?
  end

  # TODO: check based on the ownership of the bike at the time of recovery
  def recovering_user_owner?
    recovering_user.present? && bike&.owner == recovering_user
  end

  def pre_recovering_user?
    recovered_at.present? && recovered_at < self.class.recovering_user_recording_start
  end

  # At some point, we may want to associate this via the bike's ownership at time of creation or something
  def user
    bike&.user
  end

  # Only display if they have put in an address - so that we don't show on initial creation
  def display_checklist?
    address.present?
  end

  # Overrides geocodeable without_location, we need more specificity
  def without_location?
    street.blank?
  end

  # Used to be an attribute, removed in
  def show_address
    false
  end

  def address(force_show_address: false, country: [:iso, :optional])
    Geocodeable.address(
      self,
      street: force_show_address || show_address,
      country: country
    ).presence
  end

  def set_calculated_attributes
    self.phone = Phonifyer.phonify(phone)
    self.secondary_phone = Phonifyer.phonify(secondary_phone)
    self.date_stolen = self.class.corrected_date_stolen(date_stolen)
    self.street = nil unless street.present? # Make it easier to find blank addresses
    if city.present?
      self.city = city.gsub("USA", "").gsub(/,?(,|\s)[A-Z]+\s?++\z/, "").strip.titleize
    end
    update_tsved_at
    @alert_location_changed = city_changed? || country_id_changed? # Set ivar so it persists to after_commit
    self.current = false if recovered_at.present? # Make sure we set current to false if recovered
    self.recovery_display_status = calculated_recovery_display_status
    self.no_notify = !receive_notifications # TODO: replace receive_notifications with no_notify
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
    row << "#{b.html_url}\n"
    row
  end

  def calculated_recovery_display_status
    return "not_eligible" unless can_share_recovery
    return "not_displayed" if not_displayed?
    return "recovery_displayed" if recovery_display.present?
    if bike&.thumb_path&.present?
      "waiting_on_decision"
    else
      "displayable_no_photo"
    end
  end

  def add_recovery_information(info = {})
    info = ActiveSupport::HashWithIndifferentAccess.new(info)
    self.recovered_at = TimeParser.parse(info[:recovered_at], info[:timezone]) || Time.current

    update(
      current: false,
      recovered_description: info[:recovered_description],
      recovering_user_id: info[:recovering_user_id],
      index_helped_recovery: InputNormalizer.boolean(info[:index_helped_recovery]),
      can_share_recovery: InputNormalizer.boolean(info[:can_share_recovery])
    )
    notify_of_promoted_alert_recovery
    true
  end

  def find_or_create_recovery_link_token
    return @find_or_create_recovery_link_token if defined?(@find_or_create_recovery_link_token)

    @find_or_create_recovery_link_token = if recovery_link_token
      recovery_link_token
    elsif ApplicationRecord.current_role != :reading
      # set recovery_link_token, unless in read replica
      update(recovery_link_token: SecurityTokenizer.new_token, skip_update: true)
      recovery_link_token
    else
      enqueue_worker
      nil
    end
  end

  # If there isn't any image and there is a theft alert, we want to tell the user to upload an image
  def promoted_alert_missing_photo?
    current_alert_image.blank? && promoted_alerts.any?
  end

  # The associated bike's first public image, if available. Else nil.
  def bike_main_image
    bike&.public_images&.first
  end

  def current_alert_image
    return @current_alert_image if defined?(@current_alert_image)

    @current_alert_image = if alert_image
      alert_image
    elsif ApplicationRecord.current_role != :reading
      # Generate alert image, unless in read replica
      generate_alert_image
    else
      enqueue_worker
      nil
    end
  end

  # Generate the "promoted alert image"
  # (One of the stolen bike's public images, placed on a branded template)
  #
  # The URL is available immediately - processing is performed in the background.
  # bike_image: [PublicImage]
  def generate_alert_image(bike_image: bike_main_image)
    alert_image&.destroy # Destroy before returning if the bike has no images - in case image was removed
    return if bike_image&.image.blank? && bike&.stock_photo_url.blank?

    new_image = AlertImage.new(stolen_record: self)

    # Try to fallback to main image
    bike_image = bike_main_image if bike_image&.image.blank?
    if bike_image&.image.blank?
      new_image.remote_image_url = bike.stock_photo_url
    else
      new_image.image = bike_image.image
    end
    new_image.save

    if new_image.valid?
      new_image
    else
      update(alert_image: nil) if alert_image.id.present?
      nil
    end
  end

  def update_associations
    return true if skip_update
    # Bump bike only if it looks like this is bike's current_stolen_record
    if current || bike&.current_stolen_record_id == id
      bike&.update(manual_csr: true, current_stolen_record: (current ? self : nil))
    end
    StolenBike::AfterStolenRecordSaveJob.perform_async(id, @alert_location_changed)
    AfterUserChangeJob.perform_async(bike.user_id) if bike&.user_id.present?
  end

  private

  # The read replica can't make database changes, but can enqueue the worker - which will make the changes
  def enqueue_worker
    StolenBike::AfterStolenRecordSaveJob.perform_async(id)
  end

  def notify_of_promoted_alert_recovery
    return unless recovered? && promoted_alerts.any?

    EmailPromotedAlertNotificationJob
      .perform_async(promoted_alerts.last.id, "promoted_alert_recovered")
  end

  def all_location_attributes_present?
    return false if country_id.blank? || city.blank? || zipcode.blank?
    (country_id == Country.united_states.id) ? state_id.present? : true
  end
end
