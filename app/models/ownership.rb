class Ownership < ApplicationRecord
  attr_accessor :creator_email, :user_email

  validates_presence_of :owner_email
  validates_presence_of :creator_id
  validates_presence_of :bike_id
  validates :owner_email,
    format: {with: /\A.+@.+\..+\z/, message: "invalid format"}

  belongs_to :bike, touch: true
  belongs_to :user, touch: true
  belongs_to :creator, class_name: "User"
  belongs_to :impound_record

  default_scope { order(:created_at) }
  scope :current, -> { where(current: true) }

  before_validation :set_calculated_attributes
  after_commit :send_notification_and_update_other_ownerships, on: :create

  def first?
    bike&.ownerships&.reorder(:created_at)&.first&.id == id
  end

  def claimed?
    claimed
  end

  def self_made?
    creator_id == user_id
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
    self.user_id ||= u.id if u.present?
    save
  end

  def claimable_by?(u)
    u == User.fuzzy_email_find(owner_email) || u == user
  end

  def organization
    # If this is the first ownership, use the creation organization
    return bike.creation_organization if first?
    # Otherwise, this is only an organization ownership if it's an impound transfer
    impound_record&.organization
  end

  def calculated_send_email
    return false if !send_email || bike.blank? || bike.example? || spam_risky_email?
    # Unless this is the first ownership for a bike with a creation organization, it's good to send!
    return true unless organization.present?
    !organization.enabled?("skip_ownership_email")
  end

  def set_calculated_attributes
    self.owner_email = EmailNormalizer.normalize(owner_email)
    if id.blank? # Some things to set only on create
      self.user_id ||= User.fuzzy_email_find(owner_email)&.id
      self.claimed ||= self_made?
    end
  end

  def send_notification_and_update_other_ownerships
    if bike.present?
      bike.ownerships.current.where.not(id: id).each { |o| o.update(current: false) }
    end
    # Note: this has to be performed later; we create ownerships and then delete them, in BikeCreator
    # We need to be sure we don't accidentally send email for ownerships that will be deleted
    EmailOwnershipInvitationWorker.perform_in(2.seconds, id)
  end

  private

  def spam_risky_email?
    risky_domains = ["@yahoo.co", "@hotmail.co"]
    return false unless owner_email.present? && risky_domains.any? { |d| owner_email.match?(d) }
    return false unless bike.creation_state.present?
    %w[lightspeed_pos ascend_pos].include?(bike.creation_state.pos_kind)
  end
end
