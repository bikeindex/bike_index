class Ownership < ActiveRecord::Base
  attr_accessible :owner_email,
    :bike_id,
    :creator_id,
    :current,
    :user_id, # is the owner
    :claimed,
    :example,
    :user_hidden,
    :send_email

  attr_accessor :creator_email, :user_email

  validates_presence_of :owner_email
  validates_presence_of :creator_id
  validates_presence_of :bike_id

  belongs_to :bike
  belongs_to :user
  belongs_to :creator, class_name: 'User'

  default_scope order(:created_at)

  before_save :normalize_email 
  def normalize_email
    self.owner_email = EmailNormalizer.new(owner_email).normalized
  end

  def name_for_creator
    if creator.name.present?
      creator.name
    else
      creator.email 
    end
  end

  def owner
    if claimed
      user
    else
      creator
    end
  end

  def mark_claimed
    self.claimed = true
    u = User.fuzzy_email_find(owner_email)
    self.user_id = u.id if u.present? && user_id.blank?
    self.save
  end

  def can_be_claimed_by(u)
    u == User.fuzzy_email_find(owner_email) || u == user
  end

  def proper_owner
    user
  end

  def proper_owner_name
    proper_owner && proper_owner.name
  end

end