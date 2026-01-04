# == Schema Information
#
# Table name: ownerships
# Database name: primary
#
#  id                            :integer          not null, primary key
#  claimed                       :boolean          default(FALSE)
#  claimed_at                    :datetime
#  current                       :boolean          default(FALSE)
#  example                       :boolean          default(FALSE), not null
#  is_new                        :boolean          default(FALSE)
#  is_phone                      :boolean          default(FALSE)
#  organization_pre_registration :boolean          default(FALSE)
#  origin                        :integer
#  owner_email                   :string(255)
#  owner_name                    :string
#  pos_kind                      :integer
#  registration_info             :jsonb
#  skip_email                    :boolean          default(FALSE)
#  status                        :integer
#  token                         :text
#  user_hidden                   :boolean          default(FALSE), not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  address_record_id             :bigint
#  bike_id                       :integer
#  bulk_import_id                :bigint
#  creator_id                    :integer
#  doorkeeper_app_id             :bigint
#  impound_record_id             :bigint
#  organization_id               :bigint
#  previous_ownership_id         :bigint
#  sale_id                       :bigint
#  user_id                       :integer
#
# Indexes
#
#  index_ownerships_on_address_record_id  (address_record_id)
#  index_ownerships_on_bike_id            (bike_id)
#  index_ownerships_on_bulk_import_id     (bulk_import_id)
#  index_ownerships_on_creator_id         (creator_id)
#  index_ownerships_on_doorkeeper_app_id  (doorkeeper_app_id)
#  index_ownerships_on_impound_record_id  (impound_record_id)
#  index_ownerships_on_organization_id    (organization_id)
#  index_ownerships_on_sale_id            (sale_id)
#  index_ownerships_on_user_id            (user_id)
#
class Ownership < ApplicationRecord
  include RegistrationInfoable
  include AddressRecorded

  ORIGIN_ENUM = {
    web: 0,
    embed: 1,
    embed_extended: 2,
    embed_partial: 3,
    api_v1: 4,
    api_v2: 5,
    api_v3: 12, # added on 2022-4-20, prior to that v3 was reported as v2 :/
    bulk_import_worker: 6,
    organization_form: 7,
    creator_unregistered_parking_notification: 8,
    impound_import: 9,
    impound_process: 11,
    transferred_ownership: 10,
    sticker: 13
  }.freeze

  validates_presence_of :owner_email
  validates_presence_of :creator_id
  validates_presence_of :bike_id
  validates :owner_email,
    format: {with: /\A.+@.+\..+\z/, message: "invalid format"},
    unless: :phone_registration?

  belongs_to :bike
  belongs_to :user
  belongs_to :creator, class_name: "User"
  belongs_to :impound_record
  belongs_to :organization
  belongs_to :bulk_import
  belongs_to :previous_ownership, class_name: "Ownership" # Not indexed, added to make queries easier
  belongs_to :doorkeeper_app, class_name: "Doorkeeper::Application", counter_cache: true, touch: true
  belongs_to :sale

  has_one :sale_sold_in, class_name: "Sale" # Mainly to distinguish from the belongs_to :sale

  has_many :notifications, as: :notifiable

  enum :status, Bike::STATUS_ENUM
  enum :pos_kind, Organization::POS_KIND_ENUM
  enum :origin, ORIGIN_ENUM

  default_scope { order(:id) }
  scope :current, -> { where(current: true) }
  scope :user_hidden, -> { where(user_hidden: true) }
  scope :not_user_hidden, -> { where(user_hidden: false) }
  scope :claimed, -> { where(claimed: true) }
  scope :initial, -> { where(previous_ownership_id: nil) }
  scope :transferred, -> { where.not(previous_ownership_id: nil) }
  scope :transferred_pre_registration, -> { left_joins(:previous_ownership).where(previous_ownerships: {organization_pre_registration: true}) }
  scope :self_made, -> { where("user_id = creator_id") }
  scope :not_self_made, -> { where("user_id != creator_id").or(where(user_id: nil)) }
  scope :with_reg_info_location, -> { where("(registration_info -> 'city') IS NOT NULL") }

  before_validation :set_calculated_attributes
  after_commit :send_notification_and_update_associations, on: :create

  attr_accessor :creator_email, :user_email, :can_edit_claimed

  def self.origins
    ORIGIN_ENUM.keys.map(&:to_s)
  end

  def self.origin_humanized(str)
    return nil unless str.present?

    str.titleize.downcase
  end

  def bike
    # Get it unscoped, because example/hidden/deleted
    @bike ||= bike_id.present? ? Bike.unscoped.find_by_id(bike_id) : nil
  end

  def bike_type
    bike&.type || "bike"
  end

  def bike_scoped
    Bike.find_by_id(bike_id)
  end

  def bike_type
    bike&.type || CycleType::DEFAULT.downcase # match BikeAttributable#type case
  end

  def initial?
    return previous_ownership_id.blank? if id.present?

    # If the ownership isn't finished being created, use the id created in set_calculated_attributes
    prior_ownerships.none?
  end

  def second?
    prior_ownerships.count == 1
  end

  def claimed?
    claimed
  end

  def self_made?
    creator_id.present? && creator_id == user_id
  end

  def new_registration?
    return true if initial? || impound_record_id.present?

    previous_ownership.present? && previous_ownership.organization_pre_registration?
  end

  def phone_registration?
    is_phone
  end

  def bulk?
    bulk_import_id.present?
  end

  def pos?
    Organization.pos?(pos_kind)
  end

  def organization_direct_unclaimed_notifications?
    organization.present? && organization.direct_unclaimed_notifications?
  end

  def creation_description
    if pos?
      pos_kind.to_s.gsub("_pos", "").humanize
    elsif bulk?
      "bulk import"
    elsif origin.present?
      return "org reg" if %w[embed_extended organization_form].include?(origin)
      return "landing page" if origin == "embed_partial"
      return "parking notification" if origin == "unregistered_parking_notification"

      self.class.origin_humanized(origin)
    end
  end

  def owner
    if claimed? && user.present?
      user
    elsif creator.present?
      creator
    else
      User.fuzzy_email_find(ENV["AUTO_ORG_MEMBER"])
    end
  end

  def send_email=(val)
    self.skip_email = !val
  end

  def send_email
    !skip_email
  end

  def mark_claimed
    self.claimed = true
    self.token = nil
    self.user_id ||= User.fuzzy_email_find(owner_email)&.id
    save
  end

  def claimable_by?(passed_user)
    passed_user == User.fuzzy_email_find(owner_email) || passed_user == user
  end

  def overridden_by_user_registration?
    return false if user.blank?

    user.user_registration_organizations.where.not(registration_info: {}).any?
  end

  def claim_message
    return nil if claimed? || !current? || user.present?

    new_registration? ? "new_registration" : "transferred_registration"
  end

  def calculated_send_email
    return false if skip_email || bike.blank? || phone_registration? || bike.example? || bike.likely_spam?
    return false if spam_risky_email? || user&.no_non_theft_notification

    # Unless this is the first ownership for a bike with a creation organization, it's good to send!
    true unless organization.present? && organization.enabled?("skip_ownership_email")
  end

  # This got a little unwieldy in #2110 - TODO, maybe - clean up
  def set_calculated_attributes
    # Gotta assign this before checking email, in case it's a phone reg
    self.is_phone ||= bike.phone_registration? if id.blank? && bike.present?
    self.owner_email ||= bike&.owner_email
    self.owner_email = EmailNormalizer.normalize(owner_email)
    self.status ||= bike&.status
    if id.blank? # Some things to set only on create
      self.current = true
      if bike.present?
        self.creator_id ||= bike.creator_id
        self.example = bike.example
        # Calculate current_impound_record, if it isn't assigned
        self.impound_record_id ||= calculated_impound_record_id
      end
      # Previous attrs to #2110
      self.user_id ||= User.fuzzy_email_find(owner_email)&.id
      self.claimed = true if self_made?
      self.token ||= SecurityTokenizer.new_short_token unless claimed?
      self.previous_ownership_id = prior_ownerships.pluck(:id).last
      self.organization_id ||= impound_record&.organization_id
      self.organization_pre_registration ||= calculated_organization_pre_registration?
      # Would this be better in BikeServices::Creator? Maybe, but specs depend on this always being set
      self.origin ||= if impound_record_id.present?
        "impound_process"
      elsif initial?
        "web"
      else
        "transferred_ownership"
      end
    end
    self.registration_info = corrected_registration_info
    self.owner_name ||= user&.name.presence || fallback_owner_name
    if claimed?
      self.claimed_at ||= Time.current
      # Update owner name always! Keep it in track
      self.owner_name = user.name if user.present?
    end
    self.address_record ||= address_record_from_registration_info
  end

  def prior_ownerships
    ownerships = Ownership.where(bike_id: bike_id)
    id.present? ? ownerships.where("id < ?", id) : ownerships
  end

  def send_notification_and_update_associations
    # TODO: post #2110 doing this - I'm not sure if it's a good idea...
    if current && id.present?
      bike&.update_column :current_ownership_id, id
      prior_ownerships.current.each { |o| o.update(current: false) }
    end
    # Note: this has to be performed later; we create ownerships and then delete them, in BikeServices::Creator
    # We need to be sure we don't accidentally send email for ownerships that will be deleted
    Email::OwnershipInvitationJob.perform_in(2.seconds, id)
  end

  def create_user_registration_for_phone_registration!(user)
    return true unless phone_registration? && current

    update(claimed: true, user_id: user.id)
    bike.update(owner_email: user.email, is_phone: false)
    bike.ownerships.create(skip_email: true, owner_email: user.email, creator_id: user.id)
  end

  # Calling this inline because ownerships are updated in background processes (except on create...)
  def corrected_registration_info
    if overridden_by_user_registration?
      UserRegistrationOrganization.universal_registration_info_for(user, registration_info)
    else
      # Only assign info with organization_uniq if org_id is present
      r_info = info_with_organization_uniq(registration_info, organization_id)
      clean_registration_info(r_info)
    end
  end

  private

  def info_with_organization_uniq(r_info, org_id = nil)
    return r_info if org_id.blank? || r_info.blank?

    # NOTE: This is deleted when the user_registration_organization processes (or will be)
    if r_info["student_id"].present?
      r_info["student_id_#{org_id}"] ||= r_info["student_id"]
    end
    if r_info["organization_affiliation"].present?
      r_info["organization_affiliation_#{org_id}"] ||= r_info["organization_affiliation"]
    end
    r_info
  end

  def clean_registration_info(r_info)
    r_info ||= {}
    # skip cleaning if it's blank
    return {} if r_info.blank?

    # The only place user_name comes from, other than a user setting it themselves, is bulk_import
    r_info["phone"] = Phonifyer.phonify(r_info["phone"])
    # bike_code should be renamed bike_sticker. Legacy ownership issue
    if r_info["bike_code"].present?
      r_info["bike_sticker"] = r_info.delete("bike_code")
    end
    r_info.reject { |_k, v| v.blank? }.except("kind") # ignore 'kind' from the address_record
  end

  def spam_risky_email?
    risky_domains = ["@yahoo.co", "@hotmail.co"]
    return false unless owner_email.present? && risky_domains.any? { |d| owner_email.match?(d) }
    return true if pos?

    embed? && organization&.spam_registrations?
  end

  def calculated_impound_record_id
    # if the previous ownership is :status_with_owner, the new ownership should be too (not registered impounded)
    return if bike.ownerships.where.not(id: nil).last&.status == "status_with_owner"

    bike.impound_records.current.last&.id
  end

  # Some organizations pre-register bikes and then transfer them.
  # This may be more complicated in the future! For now, calling this good enough.
  def calculated_organization_pre_registration?
    return false if organization_id.blank?

    self.origin = "creator_unregistered_parking_notification" if status == "unregistered_parking_notification"
    return true if creator_unregistered_parking_notification?

    self_made? && creator_id == organization&.auto_user_id
  end

  def fallback_owner_name
    return registration_info["user_name"] if registration_info["user_name"].present?

    # If it's made by PSU and not from a member of PSU, use the creator name
    if new_registration? && organization_id == 553 && creator.present? && !creator.member_of?(organization)
      creator.name
    end
  end

  def address_record_from_registration_info
    address_attrs = reg_info_location_hash
    if address_attrs.blank? && registration_info["ip_address"].present?
      address_attrs = GeocodeHelper.assignable_address_hash_for(registration_info["ip_address"], new_attrs: true)
    end
    return if address_attrs.blank?

    AddressRecord.new(bike_id: bike_id, kind: :ownership, user_id:,
      skip_geocoding: address_attrs[:latitude].present?, **address_attrs)
  end

  def reg_info_location_hash
    reg_info_location = registration_info.slice(*LOCATION_KEYS).reject { |_k, v| v.blank? }
    return unless reg_info_location.present?

    reg_info_location["postal_code"] = reg_info_location.delete("zipcode")
    reg_info_location["region_string"] = reg_info_location.delete("state")
    reg_info_location["country"] ||= "US"
    reg_info_location.with_indifferent_access
  end
end
