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

  def info_hash
    @info_hash ||= self[:info_hash].with_indifferent_access
  end

  def normalize_emails_and_find_users
    self.user_email = EmailNormalizer.normalize(user_email)
    self.user ||= User.fuzzy_confirmed_or_unconfirmed_email_find(user_email)

    self.creator_email = EmailNormalizer.normalize(creator_email)
    self.creator ||= User.fuzzy_confirmed_or_unconfirmed_email_find(creator_email)

    true
  end
end
