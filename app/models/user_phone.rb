class UserPhone < ApplicationRecord
  belongs_to :user
  has_many :notifications, as: :notifiable, dependent: :destroy

  validates_presence_of :user_id
  validates :phone, presence: true, uniqueness: {scope: :user_id}

  before_validation :normalize_phone

  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :unconfirmed, -> { where(confirmed_at: nil) }
  scope :waiting_confirmation, -> { unconfirmed.where("updated_at > ?", confirmation_timeout) }

  def self.confirmation_timeout
    Time.current - 31.minutes
  end

  def self.find_confirmation_code(str)
    waiting_confirmation.where(confirmation_code: str.gsub(/\s/, "")).first
  end

  def self.add_phone_for_user_id(user_id, phone_number)
    phone = Phonifyer.phonify(phone_number)
    matching_phone = where(user_id: user_id, phone: phone).first
    if matching_phone.present?
      if matching_phone.updated_at < Time.current - 2.minutes
        matching_phone.generate_confirmation
        matching_phone.send_confirmation_text
      end
      return matching_phone
    end
    up = new(user_id: user_id, phone: phone)
    up.generate_confirmation
    up.send_confirmation_text
    up
  end

  def normalize_phone
    self.phone = Phonifyer.phonify(phone)
    self.confirmation_code ||= new_confirmation
  end

  def confirmed?
    confirmed_at.present?
  end

  def unconfirmed?
    !confirmed?
  end

  def confirm!
    return true if confirmed?
    result = update(confirmed_at: Time.current)
    # Bump user to reset the general_alerts
    user.update(updated_at: Time.current, skip_update: false)
    result
  end

  def confirmation_display
    return nil unless confirmation_code.present?
    confirmation_code[0..2] + " " + confirmation_code[3..-1]
  end

  def confirmation_message
    "Bike Index confirmation code:  #{confirmation_display}"
  end

  def send_confirmation_text
    UserPhoneConfirmationWorker.perform_async(id) unless confirmed?
  end

  def generate_confirmation
    update_attribute :confirmation_code, new_confirmation
  end

  private

  def new_confirmation
    (SecureRandom.random_number(9e6) + 1e6).to_i
  end
end
