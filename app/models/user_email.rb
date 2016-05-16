class UserEmail < ActiveRecord::Base
  attr_accessible :email, :user_id, :old_user_id, :confirmation_token
  belongs_to :user
  belongs_to :old_user, class_name: 'User'
  validates_presence_of :user_id, :email

  scope :confirmed, -> { where('confirmation_token IS NULL') }
  scope :unconfirmed, -> { where('confirmation_token IS NOT NULL') }

  before_validation :normalize_email
  def normalize_email
    self.email = EmailNormalizer.new(email).normalized
  end

  def self.create_confirmed_primary_email(user)
    return false unless user.confirmed
    where(user_id: user.id, email: user.email).first_or_create
  end

  # def self.find_or_create_additional_emails(user_id, email_list)
  #   email_list.each do |email|
  #     next if where(user_id: user, email: email).present?
  #     ue = self.new(user_id: user_id, email: email)
  #     ue.generate_confirmation
  #     ue.send_confirmation_email
  #   end
  # end

  def self.fuzzy_find(str)
    return nil if str.blank?
    find(:first, conditions: ['lower(email) = ?', EmailNormalizer.new(str).normalized])
  end

  def self.fuzzy_user_id_find(str)
    ue = fuzzy_find(str)
    ue && ue.user_id
  end

  def self.fuzzy_user_find(str)
    ue = fuzzy_find(str)
    ue && ue.user
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

  def send_confirmation_email
    AdditinoalEmailConfirmationWorker.perform_async(user_id) unless confirmed
  end

  protected

  def generate_confirmation
    self.update_attribute :confirmation_token, (Digest::MD5.hexdigest "#{SecureRandom.hex(10)}-#{DateTime.now.to_s}")
  end
end
