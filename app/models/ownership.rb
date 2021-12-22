class Ownership < ApplicationRecord
  ORIGIN_ENUM = {
    web: 0,
    embed: 1,
    embed_extended: 2,
    embed_partial: 3,
    api_v1: 4,
    api_v2: 5,
    bulk_import_worker: 6,
    organization_form: 7,
    creator_unregistered_parking_notification: 8,
    impound_import: 9,
    transferred: 10
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

  enum status: Bike::STATUS_ENUM
  enum pos_kind: Organization::POS_KIND_ENUM
  enum origin: ORIGIN_ENUM

  default_scope { order(:id) }
  scope :current, -> { where(current: true) }
  scope :user_hidden, -> { where(user_hidden: true) }
  scope :not_user_hidden, -> { where(user_hidden: false) }
  scope :claimed, -> { where(claimed: true) }
  scope :initial, -> { where(previous_ownership_id: nil) }
  scope :transferred, -> { where.not(previous_ownership_id: nil) }

  before_validation :set_calculated_attributes
  after_commit :send_notification_and_update_other_ownerships, on: :create

  attr_accessor :creator_email, :user_email, :can_edit_claimed

  def bike
    # Get it unscoped, because example/hidden/deleted
    @bike ||= bike_id.present? ? Bike.unscoped.find_by_id(bike_id) : nil
  end

  def bike_scoped
    Bike.find_by_id(bike_id)
  end

  def first?
    # If the ownership is created, use the id created in set_calculated_attributes
    id.present? ? previous_ownership_id.blank? : prior_ownerships.none?
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
    return true if first?
    # If this was first registered to an organization and is now being transferred
    # (either because it was pre-registered or an unregistered impounded bike)
    # it counts as a new registration
    second? && calculated_organization.present?
  end

  def phone_registration?
    is_phone
  end

  def bulk?
    bulk_import_id.present?
  end

  # TODO: part of #2110 - remove, temporarily added for parity with creation_state
  def is_bulk
    bulk?
  end

  def pos?
    Organization.pos?(pos_kind)
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
      origin.humanize.downcase
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

  def calculated_organization
    return organization if organization.present?
    # If this is the first ownership, use the creation organization
    return bike.creation_organization if first?
    # TODO: part of #2110 - switch to referencing previous ownership.organization_pre_registration
    # Some organizations pre-register bikes and then transfer them.
    if second? && creator&.member_of?(bike.creation_organization)
      return bike.creation_organization
    end
    # Otherwise, this is only an organization ownership if it's an impound transfer
    impound_record&.organization
  end

  def claim_message
    return nil if claimed? || !current? || user.present?
    new_registration? ? "new_registration" : "transferred_registration"
  end

  def calculated_send_email
    return false if skip_email || bike.blank? || phone_registration? || bike.example?
    return false if spam_risky_email?
    # Unless this is the first ownership for a bike with a creation organization, it's good to send!
    return true unless calculated_organization.present?
    !calculated_organization.enabled?("skip_ownership_email")
  end

  # This got a little unwieldy in #2110 - but, it's still going on, so let it go
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
        self.impound_record_id ||= bike.impound_records.current.last&.id
      end
      # Previous attrs to #2110
      self.user_id ||= User.fuzzy_email_find(owner_email)&.id
      self.claimed ||= self_made?
      self.token ||= SecurityTokenizer.new_short_token unless claimed?
      self.previous_ownership_id = prior_ownerships.pluck(:id).last
      self.organization_pre_registration ||= calculated_organization_pre_registration?
    end
    self.registration_info = cleaned_registration_info
    # Would this be better in BikeCreator? Maybe, but specs depend on this
    self.origin ||= "web"
    if claimed?
      self.claimed_at ||= Time.current
      # Update owner name always! Keep it in track
      self.owner_name = user.name if user.present?
    end
  end

  def prior_ownerships
    ownerships = Ownership.where(bike_id: bike_id)
    id.present? ? ownerships.where("id < ?", id) : ownerships
  end

  def address_hash
    (registration_info || {}).slice("street", "city", "state", "zipcode", "state", "country")
      .with_indifferent_access
  end

  def send_notification_and_update_other_ownerships
    prior_ownerships.current.each { |o| o.update(current: false) }
    # Note: this has to be performed later; we create ownerships and then delete them, in BikeCreator
    # We need to be sure we don't accidentally send email for ownerships that will be deleted
    EmailOwnershipInvitationWorker.perform_in(2.seconds, id)
  end

  def create_user_registration_for_phone_registration!(user)
    return true unless phone_registration? && current
    update(claimed: true, user_id: user.id)
    bike.update(owner_email: user.email, is_phone: false)
    bike.ownerships.create(skip_email: true, owner_email: user.email, creator_id: user.id)
  end

  private

  def spam_risky_email?
    risky_domains = ["@yahoo.co", "@hotmail.co"]
    return false unless owner_email.present? && risky_domains.any? { |d| owner_email.match?(d) }
    pos?
  end

  def cleaned_registration_info
    return {} unless registration_info.present?
    # The only place user_name comes from, other than a user setting it themselves, is bulk_import
    self.owner_name ||= registration_info["user_name"]
    registration_info["phone"] = Phonifyer.phonify(registration_info["phone"])
    registration_info.reject { |_k, v| v.blank? }
  end

  # Some organizations pre-register bikes and then transfer them.
  # This may be more complicated in the future! For now, calling this good enough.
  def calculated_organization_pre_registration?
    return false if organization_id.blank?
    self.origin = "creator_unregistered_parking_notification" if status == "unregistered_parking_notification"
    return true if creator_unregistered_parking_notification?
    self_made? && creator_id == organization&.auto_user_id
  end
end
