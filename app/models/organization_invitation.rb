class OrganizationInvitation < ActiveRecord::Base
  attr_accessible :invitee_email,
    :inviter_id,
    :invitee_name,
    :organization,
    :organization_id,
    :inviter,
    :inviter_id,
    :membership_role,
    :admin_org_id

  attr_accessor :admin_org_id

  # We are making people fill in names. That way, everyone who is at an
  # organization has a name in the email they send when creating bikes

  acts_as_paranoid

  validates_presence_of :inviter, :organization, :invitee_email, :membership_role

  belongs_to :organization
  belongs_to :inviter, class_name: 'User', foreign_key: :inviter_id
  belongs_to :invitee, class_name: 'User', foreign_key: :invitee_id

  default_scope { order(:created_at) }
  scope :unclaimed, -> { where(redeemed: nil) }

  after_create :enqueue_notification_job
  def enqueue_notification_job
    EmailOrganizationInvitationWorker.perform_async(id)
  end

  after_create :if_user_exists_assign
  def if_user_exists_assign
    user = User.fuzzy_email_find(self.invitee_email)
    if user
      self.assign_to(user)
    end
  end

  before_save :normalize_email
  def normalize_email
    self.invitee_email = EmailNormalizer.new(invitee_email).normalized
  end

  def name_for_inviter
    if self.inviter.name.present?
      self.inviter.name
    else
      self.inviter.email
    end
  end

  after_create :update_organization_invitation_counts
  def update_organization_invitation_counts
    org = organization
    if org.available_invitation_count < 1
      org.available_invitation_count = 0
    else
      org.available_invitation_count = org.available_invitation_count - 1
      org.sent_invitation_count = org.sent_invitation_count + 1
      org.save
    end
  end

  def create_membership
    membership = Membership.new
    membership.organization = organization
    membership.user = invitee
    membership.role = membership_role
    membership.save!
  end

  def assign_to(user)
    return false if redeemed
    # This way we don't generate repeat memberships accidentally. There should be some sort of alert.
    return false if user.memberships && user.organizations.include?(organization)
    self.invitee_id = user.id
    self.redeemed = true
    save!
    if invitee_name
      user.update_attribute :name, invitee_name unless user.name.present?
    end
    create_membership
  end

end
