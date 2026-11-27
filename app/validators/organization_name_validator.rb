class OrganizationNameValidator < ActiveModel::Validator
  # The top level of routes, and /register's pages - anything else under /register is an organization slug
  INVALID_NAMES = %w[400 401 404 422 500 about accept_terms accept_vendor_terms admin ambassadors ambassadors_current
    ambassadors_how_to api ascend assets auth bike_creation_graph bike_shop_packages bike_stickers
    bike_versions bikebook bikebook_schemas bikes blogs cable choose_registration components confirm contact contact_us
    csp_reports dev_and_design discourse_authentication discuss documentation donate e_bike_rules
    ebike_rules edit_my_account embed evc false feedbacks for_advocacy for_bike_shops for_cities
    for_community_groups for_law_enforcement for_schools for_shops goodbye help how_it_works
    how_not_to_buy_stolen ikes image_resources impound_claims info integrations landing letter_opener
    lightspeed lightspeed_integration lightspeed_interface locks logout lookbook manufacturers
    manufacturers_tsv marketplace membership my_account new news none o oauth organizations ownerships
    pages payments pghero primary_activities privacy protect_your_bike public_images rails
    recede_historical_location recovery_stories refresh_historical_location register registrations
    resources resume_historical_location reverse_geocode review_impound_claims roadmap sales search
    security serials session shop sidekiq signup spokecard sso stickers stolen stolen_bike_listings
    stolen_bikes stolen_notifications store strava_integration strava_search support support_bike_index
    support_the_bike_index support_the_index terms theft_alerts theft_ring ucmerced up update_browser
    user_alerts user_emails user_embeds user_home user_phones user_root_url_redirect users vendor_signup
    vendor_terms webhooks wheel_sizes where why_donate].freeze

  def self.valid?(str)
    slugged = Slugifyer.slugify(str).tr("-", "_")
    return false if slugged.length < 2 # Gotta be at least 2 characters
    return false if INVALID_NAMES.include?(slugged)
    # If it has one extra letter from an invalid name, reject it too (plurals, etc)
    return false if INVALID_NAMES.include?(slugged.delete_suffix("s"))
    # If you add an s and it's an invalid name, reject it too
    return false if INVALID_NAMES.include?("#{slugged}s")

    true
  end

  def validate(record)
    # There's gotta be a way to put these attrs together, but too lazy to figure it out right now
    return true if [record[:name], record[:short_name], record[:slug]].all? { |str| self.class.valid?(str) }

    record.errors.add(:base, "Invalid name")
  end
end
