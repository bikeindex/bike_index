module BikeFinder
  # Find a bike with the given serial number `serial` associated with email
  # address `owner_email`.
  #
  # Matches based on the normalized serial number, and `owner_email` should be
  # found via:
  #
  # - the bike's owner_email attribute
  # - the email attribute of any of the bike's owner's (user / creator: via bike.ownerships)
  # - any email associated with any owner (via user.user_emails)
  #
  # Return a Bike object, or nil
  def self.find_matching(serial:, owner_email:)
    email = EmailNormalizer.normalize(owner_email)

    candidate_user_ids =
      User
        .joins("LEFT JOIN user_emails ON user_emails.user_id = users.id")
        .where("users.email = ? OR user_emails.email = ?", email, email)
        .select(:id)
        .uniq

    Bike
      .joins("LEFT JOIN ownerships ON bikes.id = ownerships.bike_id")
      .where(serial_normalized: SerialNormalizer.new(serial: serial).normalized)
      .where(
        "bikes.owner_email = ? OR ownerships.user_id IN (?) OR ownerships.creator_id IN (?)",
        owner_email,
        candidate_user_ids,
        candidate_user_ids
      )
      .first
  end
end
