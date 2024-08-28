# == Schema Information
#
# Table name: bikes
#
#  id                          :integer          not null, primary key
#  address_set_manually        :boolean          default(FALSE)
#  all_description             :text
#  belt_drive                  :boolean          default(FALSE), not null
#  cached_data                 :text
#  city                        :string
#  coaster_brake               :boolean          default(FALSE), not null
#  credibility_score           :integer
#  cycle_type                  :integer          default("bike")
#  deleted_at                  :datetime
#  description                 :text
#  example                     :boolean          default(FALSE), not null
#  extra_registration_number   :string(255)
#  frame_material              :integer
#  frame_model                 :text
#  frame_size                  :string(255)
#  frame_size_number           :float
#  frame_size_unit             :string(255)
#  front_tire_narrow           :boolean
#  handlebar_type              :integer
#  is_for_sale                 :boolean          default(FALSE), not null
#  is_phone                    :boolean          default(FALSE)
#  latitude                    :float
#  likely_spam                 :boolean          default(FALSE)
#  listing_order               :integer
#  longitude                   :float
#  made_without_serial         :boolean          default(FALSE), not null
#  manufacturer_other          :string(255)
#  mnfg_name                   :string(255)
#  name                        :string(255)
#  neighborhood                :string
#  number_of_seats             :integer
#  occurred_at                 :datetime
#  owner_email                 :text
#  pdf                         :string(255)
#  propulsion_type             :integer          default("foot-pedal")
#  rear_tire_narrow            :boolean          default(TRUE)
#  serial_normalized           :string(255)
#  serial_normalized_no_space  :string
#  serial_number               :string(255)      not null
#  serial_segments_migrated_at :datetime
#  status                      :integer          default("status_with_owner")
#  stock_photo_url             :string(255)
#  street                      :string
#  thumb_path                  :text
#  updated_by_user_at          :datetime
#  user_hidden                 :boolean          default(FALSE), not null
#  video_embed                 :text
#  year                        :integer
#  zipcode                     :string(255)
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  country_id                  :integer
#  creation_organization_id    :integer
#  creator_id                  :integer
#  current_impound_record_id   :bigint
#  current_ownership_id        :bigint
#  current_stolen_record_id    :integer
#  front_gear_type_id          :integer
#  front_wheel_size_id         :integer
#  manufacturer_id             :integer
#  model_audit_id              :bigint
#  paint_id                    :integer
#  primary_frame_color_id      :integer
#  rear_gear_type_id           :integer
#  rear_wheel_size_id          :integer
#  secondary_frame_color_id    :integer
#  state_id                    :bigint
#  tertiary_frame_color_id     :integer
#  updator_id                  :integer
#
class Bike < ApplicationRecord
  include ActiveModel::Dirty
  include BikeSearchable
  include BikeAttributable
  include Geocodeable
  include PgSearch::Model

  PUBLIC_COORD_LENGTH = 2 # Truncate public coordinates decimal length

  acts_as_paranoid without_default_scope: true

  mount_uploader :pdf, PdfUploader
  process_in_background :pdf, CarrierWaveProcessWorker

  STATUS_ENUM = {
    status_with_owner: 0,
    status_stolen: 1,
    status_abandoned: 2,
    status_impounded: 3,
    unregistered_parking_notification: 4
  }.freeze

  belongs_to :updator, class_name: "User"
  belongs_to :current_stolen_record, class_name: "StolenRecord"
  belongs_to :current_impound_record, class_name: "ImpoundRecord"
  belongs_to :current_ownership, class_name: "Ownership"
  belongs_to :creator, class_name: "User" # to be deprecated and removed
  belongs_to :creation_organization, class_name: "Organization" # to be deprecated and removed
  belongs_to :paint, counter_cache: true # Not in BikeAttributable because of counter cache
  belongs_to :model_audit

  has_many :bike_organizations
  has_many :organizations, through: :bike_organizations
  has_many :can_edit_claimed_bike_organizations, -> { can_edit_claimed }, class_name: "BikeOrganization"
  has_many :can_edit_claimed_organizations, through: :can_edit_claimed_bike_organizations, source: :organization
  # delegate :creator, to: :ownership, source: :creator
  # has_one :creation_organization, through: :ownership, source: :organization
  has_many :stolen_notifications
  has_many :stolen_records, -> { current_and_not }
  has_many :impound_claims_submitting, through: :stolen_records, source: :impound_claims
  has_many :stolen_bike_listings
  has_many :normalized_serial_segments
  has_many :ownerships
  has_many :bike_versions
  has_many :bike_stickers
  has_many :b_params, foreign_key: :created_bike_id
  has_many :duplicate_bike_groups, -> { unignored }, through: :normalized_serial_segments
  has_many :duplicate_bikes_including_self, through: :duplicate_bike_groups, class_name: "Bike", source: :bikes
  has_many :recovered_records, -> { recovered_ordered }, class_name: "StolenRecord"
  has_many :impound_records
  has_many :impound_claims_claimed, through: :impound_records, source: :impound_claims
  has_many :parking_notifications
  has_many :graduated_notifications
  has_many :notifications
  has_many :theft_surveys, -> { theft_survey }, class_name: "Notification"
  has_many :theft_alerts

  accepts_nested_attributes_for :stolen_records
  accepts_nested_attributes_for :impound_records
  accepts_nested_attributes_for :components, allow_destroy: true

  validates_presence_of :serial_number
  validates_presence_of :propulsion_type
  validates_presence_of :cycle_type
  validates_presence_of :creator, on: :create
  validates_presence_of :manufacturer_id

  validates_presence_of :primary_frame_color_id

  attr_accessor :date_stolen, :receive_notifications, :has_no_serial, # has_no_serial included because legacy b_params, delete 2019-12
    :image, :image_cache, :b_param_id, :embeded, :embeded_extended, :paint_name,
    :bike_image_cache, :send_email, :skip_email, :marked_user_hidden, :marked_user_unhidden,
    :b_param_id_token, :parking_notification_kind, :skip_status_update, :manual_csr,
    :bike_sticker

  attr_writer :phone, :user_name, :external_image_urls # reading is managed by a method

  enum status: STATUS_ENUM

  delegate :bulk_import, :claimed?, :creation_description,
    :creator_unregistered_parking_notification?, :owner, :owner_name, :pos?,
    :pos_kind, :registration_info, :user, :user_id,
    :student_id, :student_id=, :organization_affiliation, :organization_affiliation=,
    to: :current_ownership, allow_nil: true

  scope :without_location, -> { where(latitude: nil) }
  scope :motorized, -> { where(propulsion_type: PropulsionType::MOTORIZED) }
  scope :current, -> { where(example: false, user_hidden: false, deleted_at: nil, likely_spam: false) }
  scope :claimed, -> { includes(:ownerships).where(ownerships: {claimed: true}) }
  scope :unclaimed, -> { includes(:ownerships).where(ownerships: {claimed: false}) }
  scope :not_stolen, -> { where.not(status: %w[status_stolen status_abandoned]) }
  scope :not_abandoned, -> { where.not(status: "status_abandoned") }
  scope :stolen_or_impounded, -> { where(status: %w[status_impounded status_stolen]) }
  scope :abandoned_or_impounded, -> { where(status: %w[status_abandoned status_impounded]) }
  scope :not_abandoned_or_impounded, -> { where.not(status: %w[status_abandoned status_impounded]) }
  scope :organized, -> { where.not(creation_organization_id: nil) }
  scope :unorganized, -> { where(creation_organization_id: nil) }
  scope :with_known_serial, -> { where.not(serial_number: "unknown") }
  scope :impounded, -> { includes(:impound_records).where(impound_records: {resolved_at: nil}).where.not(impound_records: {id: nil}) }
  scope :lightspeed_pos, -> { includes(:ownerships).where(ownerships: {pos_kind: "lightspeed_pos"}) }
  scope :ascend_pos, -> { includes(:ownerships).where(ownerships: {pos_kind: "ascend_pos"}) }
  scope :any_pos, -> { includes(:ownerships).where.not(ownerships: {pos_kind: "no_pos"}) }
  scope :does_not_need_pos, -> { includes(:ownerships).where(ownerships: {pos_kind: "does_not_need_pos"}) }
  scope :pos_not_lightspeed_ascend, -> { includes(:ownerships).where.not(ownerships: {pos_kind: %w[lightspeed_pos ascend_pos no_pos]}) }
  scope :no_pos, -> { includes(:ownerships).where(ownerships: {pos_kind: "no_pos"}) }
  scope :spam, -> { unscoped.where(likely_spam: true) }
  scope :not_spam, -> { where(likely_spam: false) }
  scope :example, -> { unscoped.where(example: true) }
  scope :non_example, -> { where(example: false) }
  scope :ignored, -> { where(example: true).or(where.not(deleted_at: nil)).or(where(likely_spam: true)) }
  scope :with_user_hidden, -> { unscoped.non_example.not_spam.without_deleted }
  scope :default_includes, -> { includes(:primary_frame_color, :secondary_frame_color, :tertiary_frame_color, :current_stolen_record, :current_ownership) }

  default_scope -> { default_includes.current.order(listing_order: :desc) }

  before_validation :set_calculated_attributes
  after_commit :enqueue_duplicate_bike_finder_worker, on: :destroy

  pg_search_scope :pg_search, against: {
    serial_number: "A",
    cached_data: "B",
    all_description: "C"
  }

  pg_search_scope :admin_search,
    against: {owner_email: "A"},
    associated_against: {ownerships: :owner_email, creator: :email},
    using: {tsearch: {dictionary: "english", prefix: true}}

  class << self
    def statuses
      STATUS_ENUM.keys.map(&:to_s)
    end

    def status_humanized(str)
      status = str.to_s&.gsub("status_", "")&.tr("_", " ")
      status == "unregistered parking notification" ? "unregistered" : status
    end

    def status_humanized_translated(str)
      return "" unless str.present?
      I18n.t(str.tr(" ", "_"), scope: [:activerecord, :status_humanized, :bike])
    end

    def text_search(query)
      query.present? ? pg_search(query) : all
    end

    def organized_email_and_name_search(query)
      return all unless query.present?
      query_string = "%#{query.strip}%"
      includes(:current_ownership)
        .where("bikes.owner_email ilike ? OR ownerships.owner_name ilike ?", query_string, query_string)
        .references(:current_ownership)
    end

    def admin_text_search(query)
      query.present? ? admin_search(query) : all
    end

    def search_phone(str)
      q = "%#{Phonifyer.phonify(str)}%"
      unscoped.includes(:stolen_records)
        .where("stolen_records.phone ILIKE ? OR stolen_records.secondary_phone ILIKE ?", q, q)
        .distinct.references(:stolen_records)
    end

    def friendly_find(bike_str)
      return nil unless bike_str.present?
      bike_str = bike_str.to_s.strip
      bike_id = if /^\d+\z/.match?(bike_str) # it's only numbers
        bike_str
      else # Check if it's a bike URL
        b_id = bike_str.match(/bikes\/\d*/i)
        b_id && b_id[0].gsub(/bikes./, "")
      end.to_i
      # Return nil if above max unsinged 4 bit integer size (how we're storing IDs)
      return nil if bike_id.blank? || bike_id > 2147483647
      where(id: bike_id).first
    end

    # This method only accepts numerical org ids
    def bike_sticker(organization_id = nil)
      return includes(:bike_stickers).where.not(bike_stickers: {bike_id: nil}) if organization_id.blank?
      includes(:bike_stickers).where(bike_stickers: {organization_id: organization_id})
    end

    # This method doesn't accept org_id because Seth got lazy
    def no_bike_sticker
      includes(:bike_stickers).where(bike_stickers: {bike_id: nil})
    end

    def organization(org_or_org_ids)
      ids = org_or_org_ids.is_a?(Organization) ? org_or_org_ids.id : org_or_org_ids
      includes(:bike_organizations).where(bike_organizations: {organization_id: ids})
    end

    # Possibly-found bikes are stolen bikes that have a counterpart record(s)
    # (matching by normalized serial number) in an abandoned state.
    def possibly_found
      unscoped
        .current
        .status_stolen
        .where(serial_normalized: abandoned_or_impounded.select(:serial_normalized))
    end

    # Return an array of tuples, each pairing a possibly-found bike with a
    # counterpart abandoned bike.
    def possibly_found_with_match
      matches_by_serial =
        unscoped
          .current
          .abandoned_or_impounded
          .where.not(serial_normalized: nil)
          .group_by(&:serial_normalized)

      possibly_found
        .select { |bike| matches_by_serial.key?(bike.serial_normalized) }
        .map { |bike| [bike, matches_by_serial[bike.serial_normalized]] }
        .flat_map { |bike, matches| matches.map { |match| [bike, match] } }
        .reject { |bike, match| bike.owner_email == match.owner_email }
    end

    # Externally possibly-found bikes are stolen bikes that have a counterpart
    # record(s) (matching by normalized serial number) in an external registry.
    #
    # External-registry searches can be delimited by country by passing
    # `country_iso`.
    def possibly_found_externally(country_iso: "NL")
      normalized_serials =
        ExternalRegistryBike
          .where(country: Country.where(iso: country_iso))
          .where.not(serial_normalized: nil)
          .select(:serial_normalized)
          .distinct
          .pluck(:serial_normalized)

      unscoped
        .current
        .currently_stolen_in(country: country_iso)
        .not_abandoned
        .where(serial_normalized: normalized_serials)
    end

    # Return an array of tuples, each pairing a possibly-found bike with a
    # counterpart possible match found on an external registry associated with
    # the given `country_iso`.
    def possibly_found_externally_with_match(country_iso: "NL")
      matches_by_serial =
        ExternalRegistryBike
          .where(country: Country.where(iso: country_iso))
          .where.not(serial_normalized: nil)
          .group_by(&:serial_normalized)

      possibly_found_externally(country_iso: country_iso)
        .select { |bike| matches_by_serial.key?(bike.serial_normalized) }
        .map { |bike| [bike, matches_by_serial[bike.serial_normalized]] }
        .flat_map { |bike, matches| matches.map { |match| [bike, match] } }
    end

    # Search for currently stolen bikes reported stolen in the given city, state
    # and/or country. `city`, `state` and `country` are accepted as strings /
    # symbols of the name or abbreviation, and are matched conjointly.
    def currently_stolen_in(city: nil, state: nil, country: nil)
      location = {city: city, state: state, country: country}.select { |_, v| v.present? }
      location[:state] &&= State.find_by("name = ? OR abbreviation = ?", state, state)
      location[:country] &&= Country.find_by("name = ? OR iso = ?", country, country)
      return none if location.values.any?(&:blank?)

      unscoped
        .status_stolen
        .current
        .with_known_serial
        .includes(:current_stolen_record)
        .where(stolen_records: location)
    end
  end

  # We don't actually want to show these messages to the user, since they just tell us the bike wasn't created
  def cleaned_error_messages
    errors.full_messages.reject { |m| m[/(bike can.t be blank|are you sure the bike was created)/i] }
  end

  # Have to remove self from duplicate bike groups
  def duplicate_bikes
    duplicate_bikes_including_self.where.not(id: id)
  end

  def calculated_listing_order
    return current_stolen_record.date_stolen.to_i.abs if current_stolen_record.present?
    return current_impound_record.impounded_at.to_i.abs if current_impound_record.present?
    t = (updated_by_user_fallback || Time.current).to_i / 10000
    stock_photo_url.present? || public_images.limit(1).present? ? t : t / 100
  end

  def credibility_scorer
    CredibilityScorer.new(self)
  end

  # TODO: for impound CSV - this is a little bit of a stub, update
  def created_by_notification_or_impounding?
    return false if current_ownership.blank?
    %w[unregistered_parking_notification impound_import].include?(current_ownership.origin) ||
      current_ownership.status == "status_impounded"
  end

  # Abbreviation, checks if this is a bike_version
  def version?
    false
  end

  def display_name
    name.presence || cycle_type.titleize
  end

  def user?
    user.present?
  end

  def stolen_recovery?
    recovered_records.any?
  end

  def impounded?
    current_impound_record.present?
  end

  def avery_exportable?
    !impounded? && owner_name.present? && valid_mailing_address?
  end

  def current_parking_notification
    parking_notifications.current.first
  end

  def messages_count
    notifications.count + parking_notifications.count + Feedback.bike(id).count +
      UserAlert.where(bike_id: id).count + GraduatedNotification.where(bike_id: id).count
  end

  # The appropriate edit template to use in the edit view.
  def default_edit_template
    status_stolen? ? "theft_details" : "bike_details"
  end

  def email_visible_for?(org)
    organizations.include?(org)
  end

  # Might be more sophisticated someday...
  def serial_hidden?
    status_impounded? || unregistered_parking_notification?
  end

  def not_updated_by_user?
    updated_by_user_at.blank? || updated_by_user_at == created_at
  end

  def updated_by_user_fallback
    updated_by_user_at || updated_at
  end

  def serial_display(u = nil)
    if serial_hidden?
      # show the serial to the user, even if authorization_requires_organization?
      return "Hidden" unless authorized?(u) ||
        u&.id.present? && u.id == user&.id ||
        current_impound_record.present? && current_impound_record.authorized?(u)
    end
    return serial_number.humanize if no_serial?
    serial_number&.upcase
  end

  # Prevent returning ip address, rather than the TLD URL
  def html_url
    "#{ENV["BASE_URL"]}/bikes/#{id}"
  end

  # We may eventually remove the boolean. For now, we're just going with it.
  def made_without_serial?
    made_without_serial
  end

  def serial_unknown?
    serial_number == "unknown"
  end

  def no_serial?
    made_without_serial? || serial_unknown?
  end

  def first_ownership
    ownerships.reorder(:id).first
  end

  def organized?(org = nil)
    if org.present?
      bike_organization_ids.include?(org.id)
    else
      bike_organizations.any?
    end
  end

  def organization_graduated_notifications(org = nil)
    g_notifications = GraduatedNotification.where(bike_id: id)
    org.present? ? g_notifications.where(organization_id: org.id) : g_notifications
  end

  def graduated?(org = nil)
    organization_graduated_notifications(org).bike_graduated.any?
  end

  # check if this is the first ownership - or if no owner, which means testing probably
  def first_ownership?
    current_ownership&.blank? || current_ownership == first_ownership
  end

  def editable_organizations
    # Only the impound organization can edit it if it's impounded
    return Organization.where(id: current_impound_record.organization_id) if current_impound_record.present?
    return organizations if first_ownership? && organized? && !claimed?
    can_edit_claimed_organizations
  end

  def authorized_by_organization?(u: nil, org: nil)
    editable_organization_ids = editable_organizations.pluck(:id)
    return false unless editable_organization_ids.any?
    return true unless u.present? || org.present?
    # We have either a org or a user - if no user, we only need to check org
    return editable_organization_ids.include?(org.id) if u.blank?
    unless current_impound_record.present?
      return false if claimable_by?(u) || u == owner # authorized by owner, not organization
    end
    # Ensure the user is part of the organization and the organization can edit if passed both
    return u.member_bike_edit_of?(org) && editable_organization_ids.include?(org.id) if org.present?
    editable_organizations.any? { |o| u.member_bike_edit_of?(o) }
  end

  def first_owner_email
    first_ownership&.owner_email
  end

  def claimable_by?(u)
    return false if u.blank? || current_ownership.blank? || current_ownership.claimed?
    user == u || current_ownership.claimable_by?(u)
  end

  def authorized?(passed_user, no_superuser_override: false)
    return false if passed_user.blank?
    return true if !no_superuser_override && passed_user.superuser?
    # authorization requires organization if impounded or marked abandoned by an organization
    unless authorization_requires_organization?
      # Since it doesn't require an organization, authorize by user
      return true if passed_user == owner || claimable_by?(passed_user)
    end
    authorized_by_organization?(u: passed_user)
  end

  def authorize_and_claim_for_user(passed_user)
    return authorized?(passed_user) unless claimable_by?(passed_user)
    current_ownership.mark_claimed
    authorized?(passed_user)
  end

  # This method only accepts numerical org ids
  def bike_sticker?(organization_id = nil)
    bike_stickers.where(organization_id.present? ? {organization_id: organization_id} : {}).any?
  end

  def contact_owner?(u = nil, organization = nil)
    return false unless u.present?
    return true if status_stolen? && current_stolen_record.present?
    return false unless owner&.notification_unstolen
    return u.enabled?("unstolen_notifications") unless organization.present? # Passed organization overrides user setting to speed stuff up
    organization.enabled?("unstolen_notifications") && u.member_of?(organization)
  end

  def contact_owner_user?(u = nil, organization = nil)
    return true if user? || status_stolen? || u&.superuser?
    current_ownership&.organization_direct_unclaimed_notifications?
  end

  def contact_owner_email(u = nil, organization = nil)
    contact_owner_user?(u, organization) ? owner_email : creator&.email
  end

  def phone_registration?
    is_phone
  end

  def phone
    return owner_email if phone_registration?
    # use @phone because attr_accessor
    @phone ||= current_stolen_record&.phone
    @phone ||= user&.phone
    # Only grab the phone number from registration_info if this is the first_ownership (otherwise it should be user, etc)
    @phone ||= registration_info&.dig("phone") if first_ownership?
    @phone
  end

  def phoneable_by?(passed_user = nil)
    return false unless phone.present?
    return true if passed_user&.superuser
    if current_stolen_record.blank?
      return false unless contact_owner?(passed_user) # This return false if user isn't present
      return !passed_user.ambassador? # we aren't giving ambassadors access to phones rn
    end
    return true if current_stolen_record.phone_for_everyone
    return false if passed_user.blank?
    return true if current_stolen_record.phone_for_shops && passed_user.has_shop_membership?
    return true if current_stolen_record.phone_for_police && passed_user.has_police_membership?
    current_stolen_record.phone_for_users
  end

  def visible_by?(passed_user = nil)
    return true unless user_hidden || deleted?
    if passed_user.present?
      return true if passed_user.superuser?
      return false if deleted?
      return true if user_hidden && authorized?(passed_user)
    end
    false
  end

  def build_new_stolen_record(new_attrs = {})
    new_country_id = country_id || creator&.country_id || Country.united_states&.id
    new_stolen_record = stolen_records
      .build({country_id: new_country_id, phone: phone, current: true}.merge(new_attrs))
    new_stolen_record.date_stolen ||= Time.current # in case a blank value was passed in new_attrs
    if created_at.blank? || created_at > Time.current - 1.day
      new_stolen_record.creation_organization_id = creation_organization_id
    end
    self.status ||= "status_stolen"
    new_stolen_record
  end

  def build_new_impound_record(new_attrs = {})
    new_country_id = country_id || creator&.country_id || Country.united_states&.id
    new_impound_record = impound_records
      .build({country_id: new_country_id, status: "current", user_id: creator_id}.merge(new_attrs))
    new_impound_record.impounded_at ||= Time.current # in case a blank value was passed in new_attrs

    self.current_impound_record = new_impound_record
  end

  def fetch_current_stolen_record
    return current_stolen_record if defined?(manual_csr)
    # Don't access through association, or else it won't find without a reload
    self.current_stolen_record = StolenRecord.where(bike_id: id, current: true).reorder(:id).last
  end

  def current_record
    current_impound_record || current_stolen_record
  end

  def bike_organization_ids
    bike_organizations.pluck(:organization_id)
  end

  def bike_organization_ids=(val)
    val = val.split(",").map(&:strip) unless val.is_a?(Array)

    org_ids = val.map { |id| validated_organization_id(id) }.compact

    org_ids.each { |id| bike_organizations.where(organization_id: id).first_or_create }

    bike_organizations
      .reject { |bo| org_ids.include?(bo.organization_id) }
      .each(&:destroy)
  end

  def validated_organization_id(organization_id)
    return nil unless organization_id.present?

    organization = Organization.friendly_find(organization_id)
    return organization.id if organization.present?

    not_found = I18n.t(:not_found, scope: %i[activerecord errors models bike])
    errors.add(:organizations, "#{organization_id} #{not_found}")
    nil
  end

  def set_user_hidden
    return true unless current_ownership.present? # If ownership isn't present (eg during creation), nothing to do
    if marked_user_hidden.present? && InputNormalizer.boolean(marked_user_hidden)
      self.user_hidden = true
      current_ownership.update_attribute :user_hidden, true unless current_ownership.user_hidden
    elsif marked_user_unhidden.present? && InputNormalizer.boolean(marked_user_unhidden)
      self.user_hidden = false
      current_ownership.update_attribute :user_hidden, false if current_ownership.user_hidden
    end
  end

  def normalize_serial_number
    self.serial_number = if made_without_serial?
      "made_without_serial"
    else
      SerialNormalizer.unknown_and_absent_corrected(serial_number)
    end

    if %w[made_without_serial unknown].include?(serial_number)
      self.made_without_serial = serial_number == "made_without_serial"
      self.serial_normalized = nil
      self.serial_normalized_no_space = nil
    else
      self.made_without_serial = false
      self.serial_normalized = SerialNormalizer.new(serial: serial_number).normalized
      self.serial_normalized_no_space = SerialNormalizer.no_space(serial_normalized)
    end
    true
  end

  def create_normalized_serial_segments
    SerialNormalizer.new(serial: serial_number).save_segments(id)
  end

  def clean_frame_size
    return true unless frame_size.present? || frame_size_number.present?
    if frame_size.present? && frame_size.match(/\d+\.?\d*/).present?
      # Don't overwrite frame_size_number if frame_size_number was passed
      if frame_size_number.blank? || !frame_size_number_changed?
        self.frame_size_number = frame_size.match(/\d+\.?\d*/)[0].to_f
      end
    end

    if frame_size_unit.blank?
      self.frame_size_unit = if frame_size_number.present?
        if frame_size_number < 30 # Good guessing?
          "in"
        else
          "cm"
        end
      else
        "ordinal"
      end
    end

    self.frame_size = if frame_size_number.present?
      frame_size_number.to_s.gsub(".0", "") + frame_size_unit
    else
      case frame_size.downcase
      when /xxs/
        "xxs"
      when /x*sma/, "xs"
        "xs"
      when /sma/, "s"
        "s"
      when /med/, "m"
        "m"
      when /(lg)|(large)/, "l"
        "l"
      when /xxl/
        "xxl"
      when /x*l/, "xl"
        "xl"
      end
    end
    true
  end

  def set_paints
    self.paint_id = nil if paint_id.present? && paint_name.blank? && !paint_name.nil?
    return true unless paint_name.present?
    self.paint_name = paint_name[0] if paint_name.is_a?(Array)
    return true if Color.friendly_find(paint_name).present?
    paint = Paint.friendly_find(paint_name)
    paint = Paint.create(name: paint_name) unless paint.present?
    self.paint_id = paint.id
  end

  # THIS IS FUCKING OBNOXIOUS.
  # Somehow we need to get rid of needing to have this method. country should default to optional
  def address
    Geocodeable.address(self, country: [:optional])
  end

  def valid_mailing_address?
    addy = registration_address
    return false if addy.blank? || addy.values.all?(&:blank?)
    return false if addy["street"].blank? || addy["city"].blank?
    return true if creation_organization&.default_location.blank?
    creation_organization.default_location.address_hash != addy
  end

  def registration_address_source
    # NOTE: User address is the preferred address! If user address is set, address fields don't show on bike!
    if user&.address_set_manually
      "user"
    elsif address_set_manually
      "bike_update"
    elsif current_ownership&.address_hash.present?
      "initial_creation"
    end
  end

  def registration_address(unmemoize = false)
    # unmemoize is necessary during save, because things may have changed
    return @registration_address if !unmemoize && defined?(@registration_address)
    @registration_address = case registration_address_source
    when "user" then user&.address_hash
    when "bike_update" then address_hash
    when "initial_creation" then current_ownership.address_hash
    else
      {}
    end.with_indifferent_access
  end

  # Set the bike's location data (lat/long, city, postal code, country, etc.)
  #
  # Geolocate based on the full current stolen record address, if available.
  # Otherwise, use the data set by set_location_info.
  # Sets lat/long, will avoid a geocode API call if coordinates are found
  def set_location_info
    if current_stolen_record.present?
      # If there is a current stolen - even if it has a blank location - use it
      # It's used for searching and displaying stolen bikes, we don't want other information leaking
      self.attributes = if address_set_manually # Only set coordinates if the address is set manually
        current_stolen_record.attributes.slice("latitude", "longitude")
      else # Set the whole address from the stolen record
        current_stolen_record.address_hash
      end
    else
      if address_set_manually # If it's not stolen, use the manual set address for the coordinates
        return true unless user&.address_set_manually # If it's set by the user, address_set_manually is no longer correct!
        self.address_set_manually = false
      end
      address_attrs = location_record_address_hash
      return true unless address_attrs.present? # No address hash present so skip
      self.attributes = address_attrs
    end
  end

  def alert_image_url(version = nil)
    current_stolen_record&.current_alert_image&.image_url(version)
  end

  def external_image_urls
    b_params.map { |bp| bp.external_image_urls }.flatten.reject(&:blank?).uniq
  end

  def load_external_images(urls = nil)
    (urls || external_image_urls).reject(&:blank?).each do |url|
      next if public_images.where(external_image_url: url).present?
      public_images.create(external_image_url: url)
    end
  end

  # Called in BikeCreator, so that the serial and email can be used for dupe finding
  def set_calculated_unassociated_attributes
    clean_frame_size
    self.manufacturer_other = InputNormalizer.string(manufacturer_other)
    self.mnfg_name = Manufacturer.calculated_mnfg_name(manufacturer, manufacturer_other)
    self.frame_model = InputNormalizer.string(frame_model)
    self.owner_email = normalized_email
    normalize_serial_number
    set_paints
    self.name = InputNormalizer.string(name)
    self.extra_registration_number = InputNormalizer.string(extra_registration_number)
    if extra_registration_number.present?
      serial_sanitized = InputNormalizer.regex_escape(serial_number)
      if serial_sanitized.present? && extra_registration_number.match?(/(serial.)?#{serial_sanitized}/i)
        self.extra_registration_number = nil
      end
    end
  end

  def set_calculated_attributes
    set_calculated_unassociated_attributes
    fetch_current_stolen_record # grab the current stolen record first, it's used by a bunch of things
    fetch_current_impound_record # Used by a bunch of things, but this method is private
    self.occurred_at = calculated_occurred_at
    self.current_ownership = calculated_current_ownership
    set_location_info
    self.listing_order = calculated_listing_order
    self.status = calculated_status unless skip_status_update
    self.updated_by_user_at ||= created_at
    set_user_hidden
    # cache_bike
    self.all_description = cached_description_and_stolen_description
    self.thumb_path = public_images.limit(1)&.first&.image_url(:small)
    self.cached_data = cached_data_array.join(" ")
  end

  # Only geocode if address is set manually (and not skipping geocoding)
  def should_be_geocoded?
    return false if skip_geocoding?
    address_changed?
  end

  # Should be private. Not for now, because we're migrating (removing #stolen?, #impounded?, etc)
  def calculated_status
    return "status_impounded" if current_impound_record.present?
    return "unregistered_parking_notification" if status == "unregistered_parking_notification"
    return "status_abandoned" if status_abandoned? || parking_notifications.active.appears_abandoned_notification.any?
    return "status_stolen" if current_stolen_record.present?

    "status_with_owner"
  end

  def enqueue_duplicate_bike_finder_worker
    DuplicateBikeFinderWorker.perform_async(id)
  end

  private

  # Select the source from which to derive location data, in the following order
  # of precedence:
  #
  # 1. The current parking notification/impound record, if one is present
  # 2. #registration_address (which prioritizes user address)
  # 3. The creation organization address (so we have a general area for the bike)
  # prefer with street address, fallback to anything with a latitude, use hashes (not obj) because registration_address
  def location_record_address_hash
    l_hashes = [
      current_impound_record&.address_hash,
      current_parking_notification&.address_hash,
      registration_address(true),
      creation_organization&.default_location&.address_hash
    ].compact
    l_hash = l_hashes.find { |rec| rec&.dig("street").present? } ||
      l_hashes.find { |rec| rec&.dig("latitude").present? }
    return {} unless l_hash.present?
    # If the location record has coordinates, skip geocoding
    l_hash.merge(skip_geocoding: l_hash["latitude"].present?)
  end

  def fetch_current_impound_record
    self.current_impound_record = impound_records.current.last
  end

  def authorization_requires_organization?
    # If there is a current impound record
    current_impound_record.present? && current_impound_record.organized?
  end

  def calculated_current_ownership
    ownerships.order(:id).last
  end

  def calculated_occurred_at
    return nil if current_record.blank?
    current_impound_record&.impounded_at || current_stolen_record&.date_stolen
  end

  def normalized_email
    # If the owner_email changed, we look up the owner - skip the lookup if possible
    unless owner_email_changed?
      return user.present? ? user.email : owner_email
    end
    existing_user = User.fuzzy_email_find(owner_email)
    if existing_user.present?
      existing_user.email
    else
      EmailNormalizer.normalize(owner_email)
    end
  end

  def cached_description_and_stolen_description
    [description, current_stolen_record&.theft_description]
      .reject(&:blank?).join(" ")
  end
end
