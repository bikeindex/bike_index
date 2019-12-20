class Ownership < ApplicationRecord
  attr_accessor :creator_email, :user_email

  validates_presence_of :owner_email
  validates_presence_of :creator_id
  validates_presence_of :bike_id
  validates :owner_email,
            format: { with: /\A.+@.+\..+\z/, message: "invalid format" }

  belongs_to :bike, touch: true
  belongs_to :user, touch: true
  belongs_to :creator, class_name: "User"

  default_scope { order(:created_at) }
  scope :current, -> { where(current: true) }

  before_save :set_calculated_attributes

  def set_calculated_attributes
    self.owner_email = EmailNormalizer.normalize(owner_email)
    true # TODO: Rails 5 update
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
    self.user_id ||= u.id if u.present?
    save
  end

  def claimable_by?(u)
    u == User.fuzzy_email_find(owner_email) || u == user
  end

  def calculated_send_email
    return false if !send_email || bike.blank? || bike.example?
    # Unless this is the first ownership for a bike with a creation organization, it's good to send!
    return true unless bike.creation_organization.present? && first?
    !bike.creation_organization.paid_for?("skip_ownership_email")
  end
end
