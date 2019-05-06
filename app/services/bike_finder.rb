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
  def self.find_matching(serial:, owner_email:, current_user: nil)
    owner_email = EmailNormalizer.normalize(owner_email)
    serial = SerialNormalizer.new(serial: serial).normalized

    candidate_user_ids =
      User
        .joins("LEFT JOIN user_emails ON user_emails.user_id = users.id")
        .where("users.email = ? OR user_emails.email = ?", owner_email, owner_email)
        .select(:id)
        .uniq

    found_bike = Bike
      .joins("LEFT JOIN ownerships ON bikes.id = ownerships.bike_id")
      .where(serial_normalized: serial)
      .where(
        "bikes.owner_email = ? OR ownerships.user_id IN (?) OR ownerships.creator_id IN (?)",
        owner_email,
        candidate_user_ids,
        candidate_user_ids
      )
      .first

    return found_bike if found_bike.present?

    if current_user.present?
      Bike
        .includes(:ownerships)
        .where(serial_normalized: serial, ownerships: { claimed: true })
        .select { |b| b.creation_organization&.in?(current_user.organizations) }
        .first
    end
  end
end
