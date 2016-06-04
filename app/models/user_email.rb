class UserEmail < ActiveRecord::Base
  attr_accessible :email, :user_id, :old_user_id, :confirmation_token
  belongs_to :user, touch: true
  belongs_to :old_user, class_name: 'User', touch: true
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

  def self.add_emails_for_user_id(user_id, email_list)
    email_list.to_s.split(',').reject(&:blank?).each do |str|
      email = EmailNormalizer.new(str).normalized
      next if where(user_id: user_id, email: email).present?
      ue = self.new(user_id: user_id, email: email)
      ue.generate_confirmation
      ue.save
      ue.send_confirmation_email
    end
  end

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

  def primary
    confirmed && user.email == email
  end

  def expired
    created_at > Time.zone.now - 2.hours
  end

  def make_primary
    return false unless confirmed && !primary
    if user.user_emails.where(email: user.email).present?
      # Ensure we aren't somehow deleting an email
      # because it doesn't have a user_email associated with it
      user.update_attribute :email, email
    end
  end

  def confirm(token)
    if token == confirmation_token
      update_attribute :confirmation_token, nil
      MergeAdditionalEmailWorker.perform_async(id)
      return true
    end
  end

  def send_confirmation_email
    AdditionalEmailConfirmationWorker.perform_async(id) unless confirmed
  end

  def generate_confirmation
    self.update_attribute :confirmation_token, (Digest::MD5.hexdigest "#{SecureRandom.hex(10)}-#{DateTime.now.to_s}")
  end
end
