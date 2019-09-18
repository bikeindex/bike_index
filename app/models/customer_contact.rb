class CustomerContact < ActiveRecord::Base
  belongs_to :bike
  belongs_to :user
  belongs_to :creator, class_name: "User"

  KIND_ENUM = {
    stolen_contact: 0,
    stolen_twitter_alerter: 1,
    held_bike_notification: 2,
    externally_held_bike_notification: 3,
  }.freeze

  enum kind: KIND_ENUM

  validates \
    :bike,
    :body,
    :creator_email,
    :kind,
    :title,
    :user_email,
    presence: true

  before_save :normalize_emails_and_find_users

  def self.build_held_bike_notification(bike:, subject:, body:, sender:)
    attrs = {
      bike: bike,
      body: body,
      creator_email: sender,
      kind: :held_bike_notification,
      title: subject,
      user_email: bike.owner_email,
    }
    new(attrs)
  end

  def self.build_externally_held_bike_notification(**kwargs)
    contact = build_held_bike_notification(**kwargs)
    contact.kind = :externally_held_bike_notification
    contact
  end

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
