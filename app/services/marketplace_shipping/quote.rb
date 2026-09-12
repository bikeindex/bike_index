module MarketplaceShipping
  module Quote
    extend Functionable

    # Rates change and every call costs us, so don't ask per page view. Short enough that a quote
    # shown to a buyer is still roughly what we'd pay when they act on it.
    CACHE_EXPIRY = 12.hours

    # An estimate to show a buyer. Booking re-quotes rather than reusing this: the rateSignature
    # in the response is single-use, and the shop's measurements at drop-off supersede ours.
    #
    # destination takes :address1, :city, :region, :postal_code and :country_iso. BikeFlights
    # requires a street address at both ends, so there is no quoting from a postal code alone -
    # a buyer has to say where the bike is actually going before they can be shown a price.
    #
    # Returns nil when the listing can't ship, or either address is too incomplete to rate.
    def for_listing(marketplace_listing, destination:)
      return nil unless marketplace_listing&.shippable?

      origin = origin_address(marketplace_listing)
      return nil unless rateable?(origin) && rateable?(destination)

      # Raising out of the fetch rather than rescuing inside it matters: a rescued nil would be
      # cached, and one blip would suppress quotes on this listing for the next twelve hours.
      Rails.cache.fetch(cache_key(marketplace_listing, destination),
        expires_in: CACHE_EXPIRY, race_condition_ttl: 30.seconds) do
        Integrations::BikeFlights::Client.shop_rate(origin:, destination:,
          packages: [package(marketplace_listing)])
      end
    rescue Integrations::BikeFlights::Client::Error, Faraday::Error => e
      if Rails.env.production?
        Honeybadger.notify("BikeFlights rate request failed", error_class: name,
          context: {marketplace_listing_id: marketplace_listing.id, message: e.message})
      end
      nil
    end

    #
    # private below here
    #

    def origin_address(marketplace_listing)
      address_record = marketplace_listing.address_record
      return {} if address_record.blank?

      # region rather than region_string - US states are stored as a region_record, which leaves
      # region_string nil
      {address1: address_record.street, city: address_record.city,
       region: address_record.region, postal_code: address_record.postal_code,
       country_iso: address_record.country&.iso}
    end

    def rateable?(address)
      address.present? && address[:address1].present? && address[:postal_code].present? &&
        address[:city].present?
    end

    def package(marketplace_listing)
      MarketplaceShipping::PackageEstimator.estimate_for(marketplace_listing.item)
        .merge(value: marketplace_listing.amount)
    end

    # Keyed on the postal code rather than the full street address: a residential surcharge can
    # move the real price within one ZIP, but this is an estimate that gets re-quoted before any
    # label is bought, and keying on the street would mean a paid call per unique buyer.
    # updated_at covers the rest - price, origin address and frame size all feed the rate.
    def cache_key(marketplace_listing, destination)
      ["marketplace_shipping_quote", marketplace_listing.id,
        marketplace_listing.updated_at.to_i, normalized_postal_code(destination[:postal_code]),
        destination[:country_iso].presence || "US"].join("::")
    end

    # Buyer-typed, so "94103-1234" and " 94103" have to land on the same key as "94103"
    def normalized_postal_code(postal_code)
      postal_code.to_s.strip[/\A\d{5}/] || postal_code.to_s.strip
    end

    conceal :origin_address, :rateable?, :package, :cache_key, :normalized_postal_code
  end
end
