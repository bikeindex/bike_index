class Membership < ActiveRecord::Base
  MEMBERSHIP_TYPES = %w(admin member).freeze

  acts_as_paranoid

  belongs_to :user
  belongs_to :organization

  validates_presence_of :role, message: "How the hell did you manage to not choose a role? You have to choose one."
  validates_presence_of :organization, message: "Sorry, organization doesn't exist"
  validates_presence_of :user, message: "We're sorry, that user hasn't yet signed up for Bike Index. Please ask them to before adding them to your organization"

  after_commit :update_relationships
  after_create :ensure_ambassador_tasks_assigned!

  scope :ambassador_organizations, -> { where(organization: Organization.ambassador) }

  def self.membership_types
    MEMBERSHIP_TYPES
  end

  def admin?
    role == "admin"
  end

  def ambassador?
    organization.ambassador?
  end

  def update_relationships
    user&.update_attributes(updated_at: Time.now)
    organization&.update_attributes(updated_at: Time.now)
  end

  def ensure_ambassador_tasks_assigned!
    return unless organization.kind == "ambassador"
    AmbassadorMembershipAfterCreateWorker.perform_async(id)
  end
end
