class Membership < ActiveRecord::Base
  MEMBERSHIP_TYPES = %w(admin member).freeze

  acts_as_paranoid

  belongs_to :user
  belongs_to :organization
  belongs_to :sender, class_name: "User"

  validates_presence_of :role, :organization_id

  before_validation :set_calculated_attributes
  after_save :enqueue_processing_worker
  after_commit :update_relationships

  scope :claimed, -> { where.not(claimed_at: nil) }
  scope :ambassador_organizations, -> { where(organization: Organization.ambassador) }

  def self.membership_types
    MEMBERSHIP_TYPES
  end

  def invited_display_name
    invited_email
  end

  def send_invitation_email?
    email_invitation_sent_at.present?
  end

  def admin?
    role == "admin"
  end

  def ambassador?
    organization.ambassador?
  end

  def enqueue_processing_worker
    ProcessMembershipWorker.perform_async(id)
  end

  def set_calculated_attributes
    self.invited_email = EmailNormalizer.normalize(invited_email)
    self.claimed_at ||= Time.current if user_id.present?
  end
end
