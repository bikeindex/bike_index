class BikeOrganization < ActiveRecord::Base
  belongs_to :bike
  belongs_to :organization
  validates_presence_of :bike_id, :organization_id
  validates_uniqueness_of :organization_id, scope: [:bike_id], allow_nil: false
end
