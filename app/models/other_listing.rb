class OtherListing < ActiveRecord::Base


  belongs_to :bike
  validates_presence_of :bike_id
  validates_presence_of :url
  
end
