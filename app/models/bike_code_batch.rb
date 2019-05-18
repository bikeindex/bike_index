class BikeCodeBatch < ActiveRecord::Base
  belongs_to :user # Creator of the batch
  belongs_to :organization
  has_many :bike_codes
end
