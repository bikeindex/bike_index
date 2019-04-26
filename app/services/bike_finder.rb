module BikeFinder
  # Check for the existence of a bike with the given serial number `serial`.
  #
  # Matches based on the normalized serial number.
  # Matching is scoped to the user record associated with `owner_email`.
  #
  # Return an Bike object, or nil
  def self.find_matching(serial:, owner_email:)
    candidate_user_ids =
      User
        .joins("LEFT JOIN user_emails ON user_emails.user_id = users.id")
        .where("users.email = ? OR user_emails.email = ?", *[owner_email] * 2)
        .select(:id)
        .uniq

    return if candidate_user_ids.blank?

    normalized_serial = SerialNormalizer.new(serial: serial).normalized

    Bike
      .joins("RIGHT JOIN ownerships ON bikes.id = ownerships.bike_id")
      .where(serial_normalized: normalized_serial)
      .where("ownerships.user_id IN (?) OR ownerships.creator_id IN (?)", *[candidate_user_ids] * 2)
      .first
  end
end
