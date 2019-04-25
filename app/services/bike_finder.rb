module BikeFinder
  # Check for the existence of a bike with the given serial number `serial`.
  #
  # Matches based on the serial number and normalized serial number.
  # (TODO: on any serial number normalization?)
  # Matching is scoped to the user record associated with `owner_email`.
  #
  # Return an Bike object, or nil
  def self.find_matching(serial:, owner_email:)
    candidate_user_ids =
      User
        .joins("LEFT JOIN user_emails ON user_emails.user_id = users.id")
        .where("users.email = ? OR user_emails.email = ?", owner_email, owner_email)
        .select(:id)
        .uniq

    return if candidate_user_ids.blank?

    normalized_serial =
      SerialNormalizer
        .new(serial: serial)
        .normalized

    Bike
      .joins("RIGHT JOIN ownerships ON bikes.id = ownerships.bike_id")
      .where(serial_number: [serial, normalized_serial])
      .where("ownerships.user_id IN (?) OR ownerships.creator_id IN (?)", candidate_user_ids, candidate_user_ids)
      .first
  end
end
