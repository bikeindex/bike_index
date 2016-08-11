class MailerVariables
  def initialize(mailer_method = nil)
    @mailer_method = mailer_method
  end

  def var_hash(args = {})
    # bike_ownership_vars(bike_from_ownership(args[:ownership_id]))
  end

  # Internal methods
  # not private so we can access for testing

  def ownership_hash(ownership_id)
    ownership = ownership_id && Ownership.find(ownership_id)
    bike = bike_from_ownership(ownership)
    bike_display_hash(bike)
      .merge(
        is_new_user: !ownership.user.present?,
        is_registered_by_owner: (ownership.user.present? && bike.creator_id == ownership.user_id),
        bike_url: "#{ENV['BASE_URL']}/ownerships/#{ownership.id}"
      )
  end

  def bike_display_hash(bike)
    thumb_url = bike.thumb_path || bike.stock_photo_url || 'https://files.bikeindex.org/email_assets/bike_photo_placeholder.png'
    {
      is_new_registration: (bike.ownerships.count < 2),
      bike_type: bike.type,
      is_recovered_bike: bike.recovered,
      is_stolen_bike: bike.stolen,
      bike_url: "#{ENV['BASE_URL']}/bikes/#{bike.id}",
      bike_thumb_url: thumb_url,
      bike_manufacturer: bike.manufacturer_name,
      bike_serial: bike.serial,
      bike_paint_string: bike.frame_colors.to_sentence
    }
  end

  def bike_from_ownership(ownership = nil)
    return nil unless ownership.present?
    Bike.unscoped.find(ownership.bike_id)
  end
end
