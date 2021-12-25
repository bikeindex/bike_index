class UserRegistrationOrganization < ApplicationRecord
  acts_as_paranoid

  belongs_to :user
  belongs_to :organization

  validates_presence_of :user_id, :organization_id

  before_validation :set_calculated_attributes

  def set_calculated_all_bikes
    self.all_bikes = organization.paid?
  end

  def set_calculated_attributes
    self.bike_ids = calculated_bike_ids
  end

  private

  def calculated_bike_ids
    return user.bikes.pluck(:id) if all_bikes
    current_bike_ids = bike_ids || user.bikes.organization(organization)
    current_bike_ids & user.bikes.pluck(:id)
  end
end
