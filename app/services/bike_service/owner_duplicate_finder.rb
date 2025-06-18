# Used when registering new bikes, to prevent registering duplicate bikes
module BikeService::OwnerDuplicateFinder
  # Finds bikes with the given serial number `serial` associated with email
  # address `owner_email`.
  #
  # Matches based on the normalized serial number, and `owner_email` should be
  # found via:
  #
  # - the bike's owner_email attribute (whether it's a phone or email)
  # - the email attribute of any of the bike's owner's (user / creator: via bike.ownerships)
  # - any email associated with any owner (via user.user_emails)
  # - the phone attribute of any of the bike's owner's (user / creator: via bike.ownerships)
  # - the phone associated with any owner (via user.user_phones)
  #
  # Return a Bike object, or nil
  def self.matching(serial: nil, owner_email: nil, phone: nil, b_param: nil, manufacturer_id: nil, bikes: nil)
    email = EmailNormalizer.normalize(owner_email)
    phone = Phonifyer.phonify(phone)
    serial_normalized = SerialNormalizer.normalized_and_corrected(serial)
    return Bike.none if serial_normalized.blank?

    candidate_user_ids = find_matching_user_ids(email, phone)

    bikes ||= Bike.with_user_hidden
    matching_bikes = bikes.matching_serial(serial_normalized)
    # Only search by manufacturer_id if it's passed
    matching_bikes = matching_bikes.where(manufacturer_id: manufacturer_id) if manufacturer_id.present?
    matching_bikes.joins("LEFT JOIN ownerships ON bikes.id = ownerships.bike_id")
      .where(
        "bikes.owner_email = ? OR bikes.owner_email = ? OR ownerships.owner_email = ? OR ownerships.owner_email = ? OR ownerships.user_id IN (?)",
        email,
        phone,
        email,
        phone,
        candidate_user_ids
      )
  end

  def self.find_matching_user_ids(email = nil, phone = nil)
    return [] if email.blank? && phone.blank?
    users = User.joins("LEFT JOIN user_emails ON user_emails.user_id = users.id")
      .joins("LEFT JOIN user_phones ON user_phones.user_id = users.id")
    if email.present? && phone.present?
      users.where("users.email = ? OR user_emails.email = ? OR users.phone = ? OR user_phones.phone = ?", email, email, phone, phone)
    elsif email.present?
      users.where("users.email = ? OR user_emails.email = ?", email, email)
    elsif phone.present?
      users.where("users.phone = ? OR user_phones.phone = ?", phone, phone)
    end.distinct.pluck(:id)
  end

  private_class_method :find_matching_user_ids
end
