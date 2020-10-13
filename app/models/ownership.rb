class Ownership < ApplicationRecord
  attr_accessor :creator_email, :user_email

  validates_presence_of :owner_email
  validates_presence_of :creator_id
  validates_presence_of :bike_id
  validates :owner_email,
    format: {with: /\A.+@.+\..+\z/, message: "invalid format"},
    unless: :phone_registration?

  belongs_to :bike, touch: true
  belongs_to :user, touch: true
  belongs_to :creator, class_name: "User"
  belongs_to :impound_record

  default_scope { order(:created_at) }
  scope :current, -> { where(current: true) }
  scope :claimed, -> { where(claimed: true) }

  before_validation :set_calculated_attributes
  after_commit :send_notification_and_update_other_ownerships, on: :create

  def first?
    bike&.ownerships&.reorder(:created_at)&.first&.id == id
  end

  def claimed?
    claimed
  end

  def self_made?
    creator_id.present? && creator_id == user_id
  end

  def phone_registration?
    is_phone
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

  def mark_claimed
    self.claimed = true
    u = User.fuzzy_email_find(owner_email)
    return false unless u.present?
    self.user_id ||= u.id
    self.token = nil
    save
  end

  def claimable_by?(passed_user)
    passed_user == User.fuzzy_email_find(owner_email) || passed_user == user
  end

  def organization
    # If this is the first ownership, use the creation organization
    return bike.creation_organization if first?
    # Otherwise, this is only an organization ownership if it's an impound transfer
    impound_record&.organization
  end

  def calculated_send_email
    return false if !send_email || bike.blank? || phone_registration? || bike.example?
    return false if spam_risky_email?
    # Unless this is the first ownership for a bike with a creation organization, it's good to send!
    return true unless organization.present?
    !organization.enabled?("skip_ownership_email")
  end

  def set_calculated_attributes
    self.owner_email = EmailNormalizer.normalize(owner_email)
    if id.blank? # Some things to set only on create
      self.user_id ||= User.fuzzy_email_find(owner_email)&.id
      self.claimed ||= self_made?
      self.token ||= SecurityTokenizer.new_short_token unless claimed?
    end
    self.claimed_at ||= Time.current if claimed?
  end

  def send_notification_and_update_other_ownerships
    if bike.present?
      bike.ownerships.current.where.not(id: id).each { |o| o.update(current: false) }
    end
    # Note: this has to be performed later; we create ownerships and then delete them, in BikeCreator
    # We need to be sure we don't accidentally send email for ownerships that will be deleted
    EmailOwnershipInvitationWorker.perform_in(2.seconds, id)
  end

  def create_user_registration_for_phone_registration!(user)
    return true unless phone_registration? && current
    update(claimed: true, user_id: user.id)
    bike.update(owner_email: user.email, is_phone: false)
    bike.ownerships.create(send_email: false, owner_email: user.email, creator_id: user.id)
  end

  private

  def spam_risky_email?
    risky_domains = ["@yahoo.co", "@hotmail.co"]
    return false unless owner_email.present? && risky_domains.any? { |d| owner_email.match?(d) }
    return false unless bike.creation_state.present?
    %w[lightspeed_pos ascend_pos].include?(bike.creation_state.pos_kind)
  end
end
