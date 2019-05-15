class Ownership < ActiveRecord::Base
  attr_accessor :creator_email, :user_email

  validates_presence_of :owner_email
  validates_presence_of :creator_id
  validates_presence_of :bike_id

  belongs_to :bike, touch: true
  belongs_to :user, touch: true
  belongs_to :creator, class_name: "User"

  default_scope { order(:created_at) }
  scope :current, -> { where(current: true) }

  before_save :normalize_email

  def normalize_email
    self.owner_email = EmailNormalizer.normalize(owner_email)
  end

  def first?; bike&.ownerships&.reorder(:created_at)&.first&.id == id end

  def claimed?; claimed end

  def owner
    if claimed? && user.present?
      user
    elsif creator.present?
      creator
    else
      User.fuzzy_email_find(ENV["AUTO_ORG_MEMBER"])
    end
  end

  def mark_claimed
    self.claimed = true
    u = User.fuzzy_email_find(owner_email)
    self.user_id = u.id if u.present? && user_id.blank?
    save
  end

  def claimable_by?(u)
    u == User.fuzzy_email_find(owner_email) || u == user
  end
end
