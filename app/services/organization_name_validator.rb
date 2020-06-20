class OrganizationNameValidator
  # These were pulled from the top level of routes
  INVALID_NAMES = %w[400 401 404 422 500 about accept_terms accept_vendor_terms admin ambassadors ambassadors_current
                     ambassadors_how_to api ascend auth bike_creation_graph bike_shop_packages bike_stickers bikes
                     blogs campus_packages choose_registration cities_packages dev_and_design discourse_authentication
                     discuss documentation edit_my_account feedbacks for_bike_shops for_cities for_community_groups
                     for_law_enforcement for_schools goodbye help how_not_to_buy_stolen ikes image_resources info
                     integrations lightspeed lightspeed_interface locks logout manufacturers manufacturers_tsv
                     my_account news o oauth organizations ownerships pages payments privacy protect_your_bike
                     public_images rails recovery_stories registrations resources serials session shop sidekiq stickers
                     stolen stolen_notifications store support_bike_index support_the_bike_index support_the_index terms
                     theft_alerts university update_browser user_emails user_embeds user_root_url_redirect users vendor_terms where].freeze

  def self.valid?(str)
    slugged = Slugifyer.slugify(str)
    return false if slugged.length < 2 # Gotta be at least 2 characters
    return false if INVALID_NAMES.include?(slugged)
    # If it has one extra letter from an invalid name, reject it too (plurals, etc)
    return false if INVALID_NAMES.include?(slugged.gsub(/.\z/, ""))
    # If you add an s and it's an invalid name, reject it too
    return false if INVALID_NAMES.include?("#{slugged}s")
    true
  end
end
