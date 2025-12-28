# == Schema Information
#
# Table name: organization_roles
# Database name: primary
#
#  id                       :integer          not null, primary key
#  claimed_at               :datetime
#  created_by_magic_link    :boolean          default(FALSE)
#  deleted_at               :datetime
#  email_invitation_sent_at :datetime
#  hot_sheet_notification   :integer          default("notification_never")
#  invited_email            :string(255)
#  receive_hot_sheet        :boolean          default(FALSE)
#  role                     :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  organization_id          :integer          not null
#  sender_id                :integer
#  user_id                  :integer
#
# Indexes
#
#  index_organization_roles_on_organization_id  (organization_id)
#  index_organization_roles_on_sender_id        (sender_id)
#  index_organization_roles_on_user_id          (user_id)
#
class OrganizationRole < ApplicationRecord
  ROLE_TYPES = %w[admin member member_no_bike_edit].freeze
  HOT_SHEET_NOTIFICATION_ENUM = {notification_never: 0, notification_daily: 1}.freeze

  acts_as_paranoid

  belongs_to :user
  belongs_to :organization
  belongs_to :sender, class_name: "User"

  enum :role, ROLE_TYPES
  enum :hot_sheet_notification, HOT_SHEET_NOTIFICATION_ENUM

  validates_presence_of :role, :organization_id, :invited_email

  before_validation :set_calculated_attributes
  after_commit :enqueue_processing_worker

  attr_accessor :skip_processing

  scope :unclaimed, -> { where(claimed_at: nil) }
  scope :claimed, -> { where.not(claimed_at: nil) }
  scope :created_by_magic_link, -> { where(created_by_magic_link: true) }
  scope :ambassador_organizations, -> { where(organization: Organization.ambassador) }
  scope :approved_organizations, -> { where(organization: Organization.approved) }

  def self.role_types
    ROLE_TYPES
  end

  def self.create_passwordless(**create_attrs)
    new_passwordless_attrs = {skip_processing: true, role: "member"}
    if create_attrs[:invited_email].present? # This should always be present...
      # We need to check for existing organization_roles because the CallbackJob::AfterUserCreateJob calls this
      existing_organization_role = OrganizationRole.find_by_invited_email(create_attrs[:invited_email])
      return existing_organization_role if existing_organization_role.present?
    end
    organization_role = create!(new_passwordless_attrs.merge(create_attrs))
    # Users::ProcessOrganizationRoleJob creates a user if the user doesn't exist, for passwordless organizations
    # because of that, we want to process this inline
    Users::ProcessOrganizationRoleJob.new.perform(organization_role.id)
    organization_role.reload
    organization_role
  end

  def self.admin_text_search(str)
    q = "%#{str.to_s.strip}%"
    left_joins(:user)
      .where("organization_roles.invited_email ILIKE ? OR users.name ILIKE ? OR users.email ILIKE ?", q, q, q)
      .references(:users)
  end

  def invited_display_name
    user.present? ? user.display_name : invited_email
  end

  def send_invitation_email?
    return false if created_by_magic_link # Don't send an email if they're already being emailed
    return false if email_invitation_sent_at.present?

    invited_email.present?
  end

  def claimed?
    claimed_at.present?
  end

  def ambassador?
    organization.ambassador?
  end

  def organization_creator?
    organization.organization_roles.minimum(:id) == id
  end

  def enqueue_processing_worker
    return true if skip_processing

    # We manually update the user, because Users::ProcessOrganizationRoleJob won't find this organization_role
    if deleted? && user_id.present?
      CallbackJob::AfterUserChangeJob.perform_async(user_id)
    else
      Users::ProcessOrganizationRoleJob.perform_async(id)
    end
  end

  def set_calculated_attributes
    self.invited_email = if invited_email.present?
      EmailNormalizer.normalize(invited_email)
    else
      user&.email # Basically, just for auto_user in orgs
    end
    self.claimed_at ||= Time.current if user_id.present?
  end
end
