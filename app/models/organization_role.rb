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
#  priority                 :integer          default(0), not null
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

  enum :role, ROLE_TYPES
  enum :hot_sheet_notification, HOT_SHEET_NOTIFICATION_ENUM

  belongs_to :user
  belongs_to :organization
  belongs_to :sender, class_name: "User"
  has_many :notifications, as: :notifiable

  validates_presence_of :role, :organization_id, :invited_email

  attr_accessor :skip_processing

  before_validation :set_calculated_attributes
  after_commit :enqueue_processing_worker

  scope :unclaimed, -> { where(claimed_at: nil) }
  scope :claimed, -> { where.not(claimed_at: nil) }
  scope :created_by_magic_link, -> { where(created_by_magic_link: true) }
  scope :ambassador_organizations, -> { where(organization: Organization.ambassador) }
  scope :approved_organizations, -> { where(organization: Organization.approved) }

  def self.role_types
    ROLE_TYPES
  end

  # Every listing of a user's roles goes through here, so they're in the order the user put them in
  def self.ordered_for(user)
    where(user_id: user.id).order(:priority, :id)
  end

  # The role an organization grants to anyone on its user_email_domain. Nobody invited them, so
  # stamp email_invitation_sent_at to suppress the invitation - it would otherwise arrive
  # alongside whatever email the signup itself is already sending them.
  def self.create_for_user_email_domain(**create_attrs)
    default_attrs = {skip_processing: true, role: "member", email_invitation_sent_at: Time.current}
    if create_attrs[:invited_email].present? # This should always be present...
      # We need to check for existing organization_roles because the CallbackJobs::AfterUserCreateJob calls this.
      # Scoped to the organization - an invite to a different one says nothing about this one.
      existing_organization_role = find_by(organization_id: create_attrs[:organization_id],
        invited_email: EmailNormalizer.normalize(create_attrs[:invited_email]))
      return existing_organization_role if existing_organization_role.present?
    end
    organization_role = create!(default_attrs.merge(create_attrs))
    # Process inline so the caller gets back a role already linked to its user
    Users::ProcessOrganizationRoleJob.new.perform(organization_role.id)
    organization_role.reload
    organization_role
  end

  def self.admin_text_search(str)
    q = "%#{str.to_s.strip.downcase}%"
    left_joins(:user)
      .where("organization_roles.invited_email LIKE ? OR users.name ILIKE ? OR users.email LIKE ?", q, q, q)
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

  # The organization's permanent API token creates bikes, so it goes to the roles that can
  def organization_access_token
    organization.access_token unless member_no_bike_edit?
  end

  def organization_creator?
    organization.organization_roles.minimum(:id) == id
  end

  def enqueue_processing_worker
    return true if skip_processing

    # We manually update the user, because Users::ProcessOrganizationRoleJob won't find this organization_role
    if deleted? && user_id.present?
      CallbackJobs::AfterUserChangeJob.perform_async(user_id)
    else
      Users::ProcessOrganizationRoleJob.perform_async(id)
    end
  end

  # Priority 0 is the organization the user has on by default - without one, their list starts at 1
  def on_by_default?
    priority.zero?
  end

  # An admin leaving could strand the organization, and a role the organization grants by email
  # domain would only come back
  def leavable?
    return false if admin?

    !organization.enabled?("user_role_for_user_email_domain")
  end

  # Reorders the user's roles to put this one at position, counting from the first
  def reorder_to!(position)
    others = self.class.ordered_for(user).where.not(id:).to_a
    renumber(others.insert(position.clamp(0, others.length), self), priority_offset)
  end

  # The whole list renumbers, because on by default is the first organization being priority 0
  def update_on_by_default!(on_by_default)
    renumber(self.class.ordered_for(user).to_a, on_by_default ? 0 : 1)
  end

  def set_calculated_attributes
    self.invited_email = if invited_email.present?
      EmailNormalizer.normalize(invited_email)
    else
      user&.email # Basically, just for auto_user in orgs
    end
    self.claimed_at ||= Time.current if user_id.present?
    self.priority = calculated_priority if user_id_changed? && !priority_changed?
  end

  private

  # A newly joined organization goes to the end of the user's list
  def calculated_priority
    return 0 if user_id.blank?

    (self.class.where(user_id:).where.not(id:).maximum(:priority) || -1) + 1
  end

  def priority_offset
    self.class.ordered_for(user).limit(1).pick(:priority)&.clamp(0, 1) || 0
  end

  def renumber(organization_roles, offset)
    organization_roles.each_with_index do |organization_role, index|
      self.class.where(id: organization_role.id).update_all(priority: index + offset)
    end
  end
end
