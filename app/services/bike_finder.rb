module BikeFinder
  # Check for the existence of a bike with the given serial number `serial`.
  #
  # Matches based on the serial number and normalized serial number.
  # (TODO: on any serial number normalization?)
  # Matching is scoped to the user record associated with `owner_email`.
  #
  # Return a boolean
  def self.exists?(serial:, owner_email:)
    candidate_user_ids =
      User
        .joins("LEFT JOIN user_emails ON user_emails.user_id = users.id")
        .where("users.email = ? OR user_emails.email = ?", owner_email, owner_email)
        .select(:id)
        .uniq

    return false if candidate_user_ids.blank?

    normalized_serial =
      SerialNormalizer
        .new(serial: serial)
        .normalized

    Bike
      .includes(:ownerships)
      .where(serial_number: [serial, normalized_serial])
      .where("ownerships.user_id IN (?) OR ownerships.creator_id IN (?)", candidate_user_ids, candidate_user_ids)
      .exists?
  end
end
