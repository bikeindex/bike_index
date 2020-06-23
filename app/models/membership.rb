class Membership < ApplicationRecord
  MEMBERSHIP_TYPES = %w(admin member).freeze
  HOT_SHEET_NOTIFICATION_ENUM = { notification_never: 0, notification_daily: 1 }.freeze

  acts_as_paranoid

  belongs_to :user
  belongs_to :organization
  belongs_to :sender, class_name: "User"

  enum hot_sheet_notification: HOT_SHEET_NOTIFICATION_ENUM

  validates_presence_of :role, :organization_id, :invited_email

  before_validation :set_calculated_attributes
  after_commit :enqueue_processing_worker, if: :persisted?

  attr_accessor :skip_processing

  scope :unclaimed, -> { where(claimed_at: nil) }
  scope :claimed, -> { where.not(claimed_at: nil) }
  scope :admin, -> { where(role: "admin") }
  scope :created_by_magic_link, -> { where(created_by_magic_link: true) }
  scope :ambassador_organizations, -> { where(organization: Organization.ambassador) }

  def self.membership_types
    MEMBERSHIP_TYPES
  end

  def self.create_passwordless(**create_attrs)
    new_passwordless_attrs = { skip_processing: true, role: "member" }
    if create_attrs[:invited_email].present? # This should always be present...
      # We need to check for existing memberships because the AfterUserCreateWorker calls this
      existing_membership = Membership.find_by_invited_email(create_attrs[:invited_email])
      return existing_membership if existing_membership.present?
    end
    membership = create!(new_passwordless_attrs.merge(create_attrs))
    # ProcessMembershipWorker creates a user if the user doesn't exist, for passwordless organizations
    # because of that, we want to process this inline
    ProcessMembershipWorker.new.perform(membership.id)
    membership.reload
    membership
  end

  def self.admin_text_search(str)
    q = "%#{str.to_s.strip}%"
      left_joins(:user)
        .where("memberships.invited_email ILIKE ? OR users.name ILIKE ? OR users.email ILIKE ?", q, q, q)
        .references(:users)
  end

  def invited_display_name; user.present? ? user.display_name : invited_email end

  def send_invitation_email?
    return false if created_by_magic_link # Don't send an email if they're already being emailed
    return false if email_invitation_sent_at.present?
    invited_email.present?
  end

  def admin?; role == "admin" end

  def claimed?; claimed_at.present? end

  def ambassador?; organization.ambassador? end

  def enqueue_processing_worker
    return true if skip_processing
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
