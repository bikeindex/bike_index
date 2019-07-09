class Membership < ActiveRecord::Base
  MEMBERSHIP_TYPES = %w(admin member).freeze

  acts_as_paranoid

  belongs_to :user
  belongs_to :organization
  belongs_to :sender, class_name: "User"

  validates_presence_of :role, :organization_id, :invited_email

  before_validation :set_calculated_attributes
  after_commit :enqueue_processing_worker

  scope :unclaimed, -> { where(claimed_at: nil) }
  scope :claimed, -> { where.not(claimed_at: nil) }
  scope :ambassador_organizations, -> { where(organization: Organization.ambassador) }

  def self.membership_types
    MEMBERSHIP_TYPES
  end

  def invited_display_name; user.present? ? user.display_name : invited_email end

  def send_invitation_email?; email_invitation_sent_at.blank? && invited_email.present? end

  def admin?; role == "admin" end

  def claimed?; claimed_at.present? end

  def ambassador?; organization.ambassador? end

  # TODO: remove after removing organization_invitations
  def calculated_org_invite
    return nil unless user_id.present?
    OrganizationInvitation.where(organization_id: organization_id, invitee_id: user_id).first
  end

  def calculated_org_invite_email
    calculated_org_invite&.invitee_email || user&.email
  end

  def calculated_org_invite_sender_id
    calculated_org_invite&.inviter_id
  end

  def enqueue_processing_worker
    ProcessMembershipWorker.perform_async(id)
  end

  def set_calculated_attributes
    if invited_email.present?
      self.invited_email = EmailNormalizer.normalize(invited_email)
    else
      self.invited_email = user&.email # Basically, just for auto_user in orgs
    end
    self.claimed_at ||= Time.current if user_id.present?
  end
end
