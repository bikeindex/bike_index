class OtherListing < ActiveRecord::Base
  attr_accessible :bike_id, :url, :listing_type

  belongs_to :bike
  validates_presence_of :bike_id
  validates_presence_of :url
  
end
