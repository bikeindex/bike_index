class Membership < ActiveRecord::Base
  MEMBERSHIP_TYPES = %w(admin member).freeze
  def self.old_attr_accessible
    %w(organization_id role user_id).map(&:to_sym).freeze
  end
  acts_as_paranoid

  belongs_to :user
  belongs_to :organization

  validates_presence_of :role, message: 'How the hell did you manage to not choose a role? You have to choose one.'
  validates_presence_of :organization, message: "Sorry, organization doesn't exist"
  validates_presence_of :user, message: "We're sorry, that user hasn't yet signed up for Bike Index. Please ask them to before adding them to your organization"

  after_commit :update_user

  def self.membership_types
    MEMBERSHIP_TYPES
  end

  def admin?
    role == 'admin'
  end

  def update_user
    user&.update_attributes(updated_at: Time.now)
  end
end
