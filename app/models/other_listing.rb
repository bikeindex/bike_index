class OtherListing < ActiveRecord::Base
  def self.old_attr_accessible
    %w(bike_id url listing_type).map(&:to_sym).freeze
  end

  belongs_to :bike
  validates_presence_of :bike_id
  validates_presence_of :url
  
end
