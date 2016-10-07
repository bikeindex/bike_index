class Ownership < ActiveRecord::Base
  def self.old_attr_accessible
    # :user_id # is the owner
    %w(owner_email bike_id creator_id current user_id claimed example user_hidden send_email).map(&:to_sym).freeze
  end

  attr_accessor :creator_email, :user_email

  validates_presence_of :owner_email
  validates_presence_of :creator_id
  validates_presence_of :bike_id

  belongs_to :bike, touch: true
  belongs_to :user, touch: true
  belongs_to :creator, class_name: 'User'

  default_scope { order(:created_at) }
  scope :current, -> { where(current: true) }

  before_save :normalize_email
  def normalize_email
    self.owner_email = EmailNormalizer.normalize(owner_email)
  end

  def name_for_creator
    if creator.name.present?
      creator.name
    else
      creator.email
    end
  end

  def owner
    if claimed && user.present?
      user
    elsif creator.present?
      creator
    else
      User.fuzzy_email_find(ENV['AUTO_ORG_MEMBER'])
    end
  end

  def mark_claimed
    self.claimed = true
    u = User.fuzzy_email_find(owner_email)
    self.user_id = u.id if u.present? && user_id.blank?
    save
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
