module MarketplaceShipping
  module Quote
    extend Functionable

    # Rates change and every call costs us, so don't ask per page view. Short enough that a quote
    # shown to a buyer is still roughly what we'd pay when they act on it.
    CACHE_EXPIRY = 12.hours

    # Returns the parsed ShopRate response, or nil when the listing can't ship or has no origin.
    # The requestId and rateSignature in it are what create_order needs, and they're single-use.
    def for_listing(marketplace_listing, postal_code:, country_iso: "US")
      return nil unless marketplace_listing&.shippable?
      return nil if origin(marketplace_listing).blank? || postal_code.blank?

      Rails.cache.fetch(cache_key(marketplace_listing, postal_code, country_iso),
        expires_in: CACHE_EXPIRY) do
        client.shop_rate(shop_rate_params(marketplace_listing, postal_code, country_iso))
      end
    end

    #
    # private below here
    #

    # THE SHAPE HERE IS A GUESS. Their docs name the pieces a rate needs - a shop, an origin, a
    # destination, and per-package dimensions, weight and declared value - but not the exact keys.
    # Everything unverified is deliberately in this one method, so confirming it against the
    # sandbox is a single edit rather than a hunt.
    def shop_rate_params(marketplace_listing, postal_code, country_iso)
      address = origin(marketplace_listing)
      package = MarketplaceShipping::PackageEstimator.estimate_for(marketplace_listing.item)

      {
        shopName: ENV["BIKEFLIGHTS_SHOP_NAME"],
        origin: {
          postalCode: address.postal_code,
          city: address.city,
          state: address.region_string,
          country: address.country&.iso || "US"
        },
        destination: {postalCode: postal_code, country: country_iso},
        packages: [package.merge(value: marketplace_listing.amount)]
      }
    end

    def origin(marketplace_listing)
      marketplace_listing.address_record
    end

    def cache_key(marketplace_listing, postal_code, country_iso)
      ["marketplace_shipping_quote", marketplace_listing.id, postal_code, country_iso].join("::")
    end

    def client
      Integrations::BikeFlights::Client.new
    end

    conceal :shop_rate_params, :origin, :cache_key, :client
  end
end
