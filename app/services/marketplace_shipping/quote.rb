module MarketplaceShipping
  module Quote
    extend Functionable

    # Rates change and every call costs us, so don't ask per page view. Short enough that a quote
    # shown to a buyer is still roughly what we'd pay when they act on it.
    CACHE_EXPIRY = 12.hours

    # An estimate to show a buyer. Booking re-quotes rather than reusing this: the rateSignature
    # in the response is single-use, and the shop's measurements at drop-off supersede ours.
    # Returns nil when the listing can't ship or has no origin.
    def for_listing(marketplace_listing, postal_code:, country_iso: "US")
      return nil unless marketplace_listing&.shippable?

      destination = normalized_postal_code(postal_code)
      return nil if marketplace_listing.address_record.blank? || destination.blank?

      # Raising out of the fetch rather than rescuing inside it matters: a rescued nil would be
      # cached, and one blip would suppress quotes on this listing for the next twelve hours.
      Rails.cache.fetch(cache_key(marketplace_listing, destination, country_iso),
        expires_in: CACHE_EXPIRY, race_condition_ttl: 30.seconds) do
        request_rate(marketplace_listing, destination, country_iso)
      end
    rescue Integrations::BikeFlights::Client::Error, Faraday::Error => e
      if Rails.env.production?
        Honeybadger.notify("BikeFlights rate request failed", error_class: name,
          context: {marketplace_listing_id: marketplace_listing.id, postal_code:, message: e.message})
      end
      nil
    end

    #
    # private below here
    #

    def request_rate(marketplace_listing, destination, country_iso)
      address = marketplace_listing.address_record
      package = MarketplaceShipping::PackageEstimator.estimate_for(marketplace_listing.item)

      Integrations::BikeFlights::Client.shop_rate(
        origin: {postal_code: address.postal_code, city: address.city,
                 region: address.region, country_iso: address.country&.iso},
        destination: {postal_code: destination, country_iso:},
        packages: [package.merge(value: marketplace_listing.amount)]
      )
    end

    # Buyer-typed, and each distinct string is a paid call - so "94103-1234" and " 94103" have to
    # land on the same key as "94103"
    def normalized_postal_code(postal_code)
      postal_code.to_s.strip[/\A\d{5}/]
    end

    # updated_at covers the rest of the request: price, origin address and frame size all feed
    # the rate, and all of them move it
    def cache_key(marketplace_listing, destination, country_iso)
      ["marketplace_shipping_quote", marketplace_listing.id,
        marketplace_listing.updated_at.to_i, destination, country_iso].join("::")
    end

    conceal :request_rate, :normalized_postal_code, :cache_key
  end
end
