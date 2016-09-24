class BikeOrganization < ActiveRecord::Base
  belongs_to :bike
  belongs_to :organization
  validates :bike_id, :organization_id, presence: true
end
