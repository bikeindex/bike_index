# frozen_string_literal: true

module Integrations
  module BikeFlights
    # Wraps the BikeFlights shipping API: authenticate, quote a rate, buy a label, track a package.
    #
    # Their API is shop-shaped - it authenticates as a shop with an email and password rather than
    # an API key, and every operation is named for a shop. Whoever holds the account is the payer
    # of record, because creating an order charges that account's saved payment method.
    #
    # ShopRate's wire format below is confirmed against their sandbox, which validates and names
    # every missing field. The order and label shapes are still only from their docs.
    module Client
      extend Functionable

      BASE_URL = ENV.fetch("BIKEFLIGHTS_BASE_URL", "https://sandbox.bikeflights.com")
      EMAIL = ENV["BIKEFLIGHTS_EMAIL"]
      PASSWORD = ENV["BIKEFLIGHTS_PASSWORD"]
      STORE = ENV["BIKEFLIGHTS_STORE"]
      SHOP_NAME = ENV["BIKEFLIGHTS_SHOP_NAME"]

      TOKEN_CACHE_KEY = "bike_flights_token"
      # Login returns its own expiry, so this only covers a response that omits it
      TOKEN_FALLBACK_EXPIRY = 4.hours
      # Re-auth before their clock says we must, rather than racing it
      TOKEN_EXPIRY_MARGIN = 5.minutes

      LINEAR_UNIT = "IN"
      WEIGHT_UNIT = "LB"

      class Error < StandardError; end

      # Both addresses take :address1, :city, :region, :postal_code and :country_iso. address1 is
      # required at both ends - they won't rate from a postal code alone.
      def shop_rate(origin:, destination:, packages:)
        post("api/ShopRate", {
          shopName: SHOP_NAME,
          stage: {from: address_params(origin), to: address_params(destination)},
          packages: packages.map { |package| package_params(package) }
        })
      end

      # Charges the account's saved payment method. requestId and rateSignature come from the
      # matching shop_rate response and are single-use, which is how they prevent double charges.
      def create_order(request_id:, rate_signature:, purchase_order: nil)
        post("api/Order/create-shop-order", {requestId: request_id, rateSignature: rate_signature,
                                             purchaseOrder: purchase_order}.compact)
      end

      def create_label(order_id)
        post("api/Labels/create-shop-label/#{order_id}", {})
      end

      # label_type is "laser" or "thermal"; the response is a PDF stream rather than JSON
      def label(tracking_number, label_type: "laser")
        authorized_request(:get, "api/Labels/shop-label/#{tracking_number}/#{label_type}").body
      end

      def package_location(tracking_number)
        get("api/PackageLocation/#{tracking_number}")
      end

      # Countries flagged active ship both ways. Says nothing about customs or duties.
      def countries
        get("api/Data/countries")
      end

      #
      # private below here
      #

      def address_params(address)
        {address1: address[:address1], city: address[:city], stateCode: address[:region],
         postalCode: address[:postal_code],
         countryCode: address[:country_iso].presence || "US"}.compact
      end

      # They require both units rather than assuming inches and pounds
      def package_params(package)
        package.slice(:length, :width, :height, :value)
          .merge(weight: package[:weight_pounds] || package[:weight],
            linearUnit: LINEAR_UNIT, weightUnit: WEIGHT_UNIT).compact
      end

      def token
        cached = Rails.cache.read(TOKEN_CACHE_KEY)
        return cached if cached.present?

        body = login
        Rails.cache.write(TOKEN_CACHE_KEY, body["token"], expires_in: token_expires_in(body))
        body["token"]
      end

      def login
        response = connection.post("api/Authentication/login") do |req|
          req.body = {email: EMAIL, password: PASSWORD, store: STORE}.compact
        end
        raise Error, "login failed: #{response.status} #{response.body}" unless response.success?
        raise Error, "login returned no token" unless response.body.is_a?(Hash)

        response.body
      end

      # They return the expiry rather than documenting a lifetime, so read it instead of guessing
      def token_expires_in(body)
        expires_at = Time.zone.parse(body["expiration"].to_s)
        return TOKEN_FALLBACK_EXPIRY if expires_at.blank?

        [expires_at - Time.current - TOKEN_EXPIRY_MARGIN, 1.minute].max
      end

      def get(path) = parsed(authorized_request(:get, path))

      def post(path, params) = parsed(authorized_request(:post, path, params))

      def authorized_request(method, path, params = nil)
        response = connection.public_send(method, path) do |req|
          req.headers["Authorization"] = "Bearer #{token}"
          req.body = params if params.present?
        end
        raise Error, "#{method} #{path} failed: #{response.status} #{response.body}" unless response.success?

        response
      end

      def parsed(response)
        response.body.is_a?(Hash) ? response.body.with_indifferent_access : response.body
      end

      def connection
        Faraday.new(url: BASE_URL) do |con|
          con.request :json
          con.response :json, content_type: /\bjson$/
          con.adapter Faraday.default_adapter
          con.options.timeout = 10
        end
      end

      conceal :address_params, :package_params, :token, :login, :token_expires_in,
        :get, :post, :authorized_request, :parsed, :connection
    end
  end
end
