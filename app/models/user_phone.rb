class UserPhone < ApplicationRecord
  belongs_to :user
  has_many :notifications, as: :imageable, dependent: :destroy

  validates_presence_of :user_id, :phone

  before_validation :normalize_phone

  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :unconfirmed, -> { where(confirmed_at: nil) }

  def self.add_phone_for_user_id(user_id)

  end

  def normalize_phone
    self.phone = Phonifyer.phonify(phone)
  end

  def confirmed?
    confirmed_at.present?
  end

  def unconfirmed?
    !confirmed?
  end

  def generate_confirmation
    update_attribute :confirmation_token, (Digest::MD5.hexdigest "#{SecureRandom.hex(10)}-#{DateTime.current}")
  end
end
