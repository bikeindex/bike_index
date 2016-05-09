class UserEmail < ActiveRecord::Base
  attr_accessible :email, :user_id, :old_user_id, :confirmation_token
  belongs_to :user
  belongs_to :old_user, class_name: 'User'
  validates_presence_of :user_id, :email

  scope :confirmed, -> { where('confirmation_token IS NULL') }
  scope :unconfirmed, -> { where('confirmation_token IS NOT NULL') }

  def self.create_for_user(user, email: nil)
    create_attrs = { user_id: user.id, email: (email || user.email) }
    if create_attrs[:email] != user.email || !user.confirmed
      create_attrs[:confirmation_token] = Digest::MD5.hexdigest "#{SecureRandom.hex(10)}-#{DateTime.now}"
    end
    create(create_attrs)
  end

  def self.fuzzy_user_id_find(n)
    return nil if n.blank?
    u = find(:first, conditions: ['lower(email) = ?', email.downcase.strip])
    u && u.user_id
  end

  def self.fuzzy_find(n)
    u = fuzzy_user_id_find(n)
    return nil unless u
    User.find(u)
  end

  def confirmed
    confirmation_token.blank?
  end

  def unconfirmed
    !confirmed
  end

  def expired
    created_at > Time.zone.now - 2.hours
  end
end
