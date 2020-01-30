class CustomerContact < ApplicationRecord
  belongs_to :bike
  belongs_to :user
  belongs_to :creator, class_name: "User"

  KIND_ENUM = {
    stolen_contact: 0,
    stolen_twitter_alerter: 1,
    bike_possibly_found: 2,
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

  # Given a Bike `bike` and a corresponding matching record `match` (a Bike or
  # ExternalRegistryBike), determine if an email has been sent alerting the
  # current `bike` owner that the given `match` may be their found bike.
  def self.possibly_found_notification_sent?(bike, match)
    return false unless bike.present? && match.present?

    where(kind: kinds["bike_possibly_found"], bike: bike, user_email: bike.owner_email)
      .where("info_hash->>'match_id' = ?", match.id.to_s)
      .where("info_hash->>'match_type' = ?", match.class.to_s)
      .where("info_hash->>'stolen_record_id' = ?", bike&.current_stolen_record&.id.to_s)
      .exists?
  end

  # Initialize a "bike possibly found" CustomerContact object for the given
  # bike/match pair. Use Bike#email= to populate remaining attributes based on
  # the mailer-generated message.
  #
  # Example:
  #
  #     contact = CustomerContact.build_bike_possibly_found_notification(bike, match)
  #     email = CustomerMailer.bike_possibly_found_email(contact)
  #
  #     contact.email = email
  #     email.deliver_now if contact.save
  #
  def self.build_bike_possibly_found_notification(bike, match)
    new(bike: bike,
        kind: kinds["bike_possibly_found"],
        info_hash: {
          stolen_record_id: bike&.current_stolen_record&.id.to_s,
          match_type: match.class.to_s,
          match_id: match.id.to_s,
          match: match.as_json,
        })
  end

  def receives_stolen_bike_notifications?
    # Save bike to ensure current_stolen_record is set if it needs to be
    return true if bike.tap(&:save).current_stolen_record.blank?

    bike.current_stolen_record.receive_notifications?
  end

  def email=(email)
    self.title = email.subject
    self.body = email.text_part.to_s
    self.user_email = email.to.first
    self.creator_email = email.from.first
  end

  def matching_bike
    return unless info_hash["match_type"].present? && info_hash["match_id"].present?

    match_class = info_hash["match_type"]
    match_id = info_hash["match_id"]

    match_class.constantize.find_by(id: match_id)
  end

  def normalize_emails_and_find_users
    self.user_email = EmailNormalizer.normalize(user_email)
    self.user ||= User.fuzzy_confirmed_or_unconfirmed_email_find(user_email)

    self.creator_email = EmailNormalizer.normalize(creator_email)
    self.creator ||= User.fuzzy_confirmed_or_unconfirmed_email_find(creator_email)

    true
  end
end
