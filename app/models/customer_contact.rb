class CustomerContact < ActiveRecord::Base
  belongs_to :bike
  belongs_to :user
  belongs_to :creator, class_name: "User"

  validates \
    :bike,
    :body,
    :contact_type,
    :creator_email,
    :title,
    :user_email,
    presence: true

  before_save :normalize_emails_and_find_users

  # TODO: Remove below once `info_hash` migration is complete

  serialize :info_hash_text
  before_save :sync_info_hash_fields

  def info_hash
    (info_hash_text || {}).with_indifferent_access
  end

  def sync_info_hash_fields
    self[:info_hash_text] ||= self[:info_hash]
    self[:info_hash] ||= self[:info_hash_text]
  end

  # TODO: Remove above once `info_hash` migration is complete

  def normalize_emails_and_find_users
    self.user_email = EmailNormalizer.normalize(user_email)
    self.user ||= User.fuzzy_confirmed_or_unconfirmed_email_find(user_email)

    self.creator_email = EmailNormalizer.normalize(creator_email)
    self.creator ||= User.fuzzy_confirmed_or_unconfirmed_email_find(creator_email)

    true
  end
end
