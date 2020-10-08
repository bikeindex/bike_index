class UserPhone < ApplicationRecord
  belongs_to :user
  has_many :notifications, as: :notifiable, dependent: :destroy

  validates_presence_of :user_id, :phone

  before_validation :normalize_phone

  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :unconfirmed, -> { where(confirmed_at: nil) }

  def self.confirmation_timeout
    Time.current - 31.minutes
  end

  def self.find_confirmation_code(str)
    unconfirmed.where(created_at: confirmation_timeout..Time.current)
    where(confirmation_code: str.gsub(/\s/, "")).first
  end

  def self.add_phone_for_user_id(user_id, phone_number)
    phone = Phonifyer.phonify(phone_number)
    matching_phone = where(user_id: user_id, phone: phone).first
    return matching_phone if matching_phone.present?
    up = new(user_id: user_id, phone: phone)
    up.generate_confirmation
    up.send_confirmation_text
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

  def confirm!
    return true if confirmed?
    update(confirmed_at: Time.current)
  end

  def confirmation_display
    confirmation_code[0..2] + " " + confirmation_code[3..-1]
  end

  def confirmation_message
    "Bike Index confirmation code:  #{confirmation_display}"
  end

  def send_confirmation_text
    UserPhoneConfirmationWorker.perform_async(id) unless confirmed?
  end

  def generate_confirmation
    update_attribute :confirmation_code, (SecureRandom.random_number(9e6) + 1e6).to_i
  end
end
