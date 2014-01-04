# b_param stands for Bike param
class BParam < ActiveRecord::Base
  attr_accessible :params,
    :creator_id,
    :bike_title,
    :created_bike_id,
    :bike_token_id,
    :bike_errors

  serialize :params
  serialize :bike_errors

  belongs_to :created_bike, class_name: "Bike"
  belongs_to :creator, class_name: "User"
  belongs_to :bike_token
  validates_presence_of :creator

  def bike
    params[:bike]
  end

end
