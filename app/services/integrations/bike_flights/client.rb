# frozen_string_literal: true

module Integrations
  module BikeFlights
    # Wraps the BikeFlights shipping API: authenticate, quote a rate, buy a label, track a package.
    #
    # Their API is shop-shaped - it authenticates as a shop with an email and password rather than
    # an API key, and every operation is named for a shop. Whoever holds the account is the payer
    # of record, because creating an order charges that account's saved payment method.
    #
    # Every request is logged as a BikeFlightsRequest. Any failure, including a timeout or refused
    # connection, raises Client::Error - so a caller rescues that one class to keep an outage off a page.
    module Client
      extend Functionable

      BASE_URL = ENV.fetch("BIKEFLIGHTS_BASE_URL", "https://sandbox.bikeflights.com")
      EMAIL = ENV["BIKEFLIGHTS_EMAIL"]
      PASSWORD = ENV["BIKEFLIGHTS_PASSWORD"]
      SHOP_NAME = ENV.fetch("BIKEFLIGHTS_SHOP_NAME", "Bike Index")

      TOKEN_CACHE_KEY = "bike_flights_token"
      # Login returns its own expiry, so this only covers a response that omits it
      TOKEN_FALLBACK_EXPIRY = 4.hours
      # Re-auth before their clock says we must, rather than racing it
      TOKEN_EXPIRY_MARGIN = 5.minutes

      LINEAR_UNIT = "IN"
      WEIGHT_UNIT = "LB"
      # Their docs' example code; the sandbox accepts any value, so what it classifies is unconfirmed
      CONTENT_CODE = "8000"
      DESCRIPTION = "Bicycle"

      class Error < StandardError; end

      # Both addresses take :first_name, :last_name, :phone, :address1, :city, :region, :postal_code
      # and :country_iso, all required by their validation. Optional: :company, :address2, :residential.
      # Packages take :length, :width, :height (inches), :weight_pounds and :value (dollars).
      def shop_rate(origin:, destination:, packages:)
        post(:shop_rate, "api/ShopRate", {
          shopName: SHOP_NAME,
          stage: {from: address_params(origin), to: address_params(destination)},
          packages: packages.map { |package| package_params(package) }
        })
      end

      # Charges the account's saved payment method. requestId and rateSignature come from the
      # matching shop_rate response, and the requestId is single-use, which prevents double charges.
      def create_order(request_id:, rate_signature:, purchase_order: nil)
        post(:create_order, "api/Order/create-shop-order",
          {requestId: request_id, rateSignature: rate_signature, purchaseOrder: purchase_order}.compact)
      end

      def create_label(order_id) = post(:create_label, "api/Labels/create-shop-label/#{order_id}")

      # label_type is "laser" or "thermal"; the response is a PDF rather than JSON
      def label(tracking_number, label_type: "laser")
        authorized_request(:label, :get, "api/Labels/shop-label/#{tracking_number}/#{label_type}").body
      end

      def package_location(tracking_number) = get(:package_location, "api/PackageLocation/#{tracking_number}")

      # Countries flagged active ship both ways. Says nothing about customs or duties.
      def countries = get(:countries, "api/Data/countries")

      #
      # private below here
      #

      def address_params(address)
        {company: address[:company], firstName: address[:first_name], lastName: address[:last_name],
         phoneNumber: address[:phone], address1: address[:address1], address2: address[:address2],
         city: address[:city], state: address[:region], postalCode: address[:postal_code],
         countryCode: address[:country_iso].presence || "US", isResidential: address[:residential]}.compact
      end

      # They require both units rather than assuming inches and pounds
      def package_params(package)
        package.slice(:length, :width, :height, :value)
          .merge(weight: package[:weight_pounds], linearUnit: LINEAR_UNIT, weightUnit: WEIGHT_UNIT,
            contentCode: CONTENT_CODE, insideDescription: DESCRIPTION, outsideDescription: DESCRIPTION)
      end

      def token = Rails.cache.read(TOKEN_CACHE_KEY).presence || login

      def login
        body = logged_request(:login, :post, "api/Authentication/login", {email: EMAIL, password: PASSWORD}).body
        raise Error, "login returned no token" unless body.is_a?(Hash) && body["token"].present?

        Rails.cache.write(TOKEN_CACHE_KEY, body["token"], expires_in: token_expires_in(body))
        body["token"]
      end

      # They return the expiry rather than documenting a lifetime, so read it instead of guessing
      def token_expires_in(body)
        expires_at = Time.zone.parse(body["expiration"].to_s)
        return TOKEN_FALLBACK_EXPIRY if expires_at.blank?

        [expires_at - Time.current - TOKEN_EXPIRY_MARGIN, 1.minute].max
      end

      def get(kind, path) = parsed(authorized_request(kind, :get, path))

      def post(kind, path, params = nil) = parsed(authorized_request(kind, :post, path, params))

      def authorized_request(kind, method, path, params = nil)
        logged_request(kind, method, path, params, {"Authorization" => "Bearer #{token}"})
      end

      def logged_request(kind, method, path, params, headers = {})
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = connection.run_request(method, path, params, headers)
        log(kind, path, params, started_at, response_status: response.status,
          response_body: loggable_body(response))
        # A token revoked before its expiry would otherwise fail every call until it expires
        Rails.cache.delete(TOKEN_CACHE_KEY) if response.status == 401
        raise Error, "#{kind} failed: #{response.status} #{response.body}" unless response.success?

        response
      rescue Faraday::Error => e
        log(kind, path, params, started_at, error_message: e.message)
        raise Error, "#{kind} failed: #{e.message}"
      end

      def log(kind, path, params, started_at, **attributes)
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
        BikeFlightsRequest.create!(kind:, path:, request_body: params&.except(:email, :password),
          duration_ms:, **attributes)
      end

      # The label PDF isn't storable as json, and login's token mustn't be stored at all
      def loggable_body(response)
        body = response.body
        return body.except("token") if body.is_a?(Hash)

        body if body.is_a?(Array) || response.headers["content-type"].to_s.start_with?("text/")
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

      conceal :address_params, :package_params, :token, :login, :token_expires_in, :get, :post,
        :authorized_request, :logged_request, :log, :loggable_body, :parsed, :connection
    end
  end
end
