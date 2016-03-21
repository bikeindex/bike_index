class Membership < ActiveRecord::Base
  attr_accessible :organization_id, :role, :user_id
  acts_as_paranoid
  
  belongs_to :organization
  belongs_to :user

  validates_presence_of :role, message: "How the hell did you manage to not choose a role? You have to choose one."
  validates_presence_of :organization, message: "Sorry, organization doesn't exist"
  validates_presence_of :user, message: "We're sorry, that user hasn't yet signed up for the Bike Index. Please ask them to before adding them to your organization"
end
