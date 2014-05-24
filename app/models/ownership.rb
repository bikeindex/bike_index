class Ownership < ActiveRecord::Base
  attr_accessible :owner_email,
    :bike_id,
    :creator_id,
    :current,
    :user_id, # is the owner
    :claimed,
    :example,
    :send_email

  validates_presence_of :owner_email
  validates_presence_of :creator_id
  validates_presence_of :bike_id

  belongs_to :bike
  belongs_to :user
  belongs_to :creator, class_name: 'User'

  default_scope order(:created_at)

  before_save :normalize_email 
  def normalize_email
    self.owner_email.downcase.strip!
  end

  def name_for_creator
    if self.creator.name.present?
      self.creator.name
    else
      self.creator.email 
    end
  end

  def owner
    if self.claimed
      self.user
    else
      self.creator
    end
  end

  def mark_claimed
    self.claimed = true
    self.save
  end

end