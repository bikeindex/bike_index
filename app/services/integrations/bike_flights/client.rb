# frozen_string_literal: true

module Integrations
  module BikeFlights
    # Wraps the BikeFlights shipping API: authenticate, quote a rate, buy a label, track a package.
    #
    # Their API is shop-shaped - it authenticates as a shop with an email and password rather than
    # an API key, and every operation is named for a shop. Whoever holds the account is the payer
    # of record, because creating an order charges that account's saved payment method.
    #
    # The request and response shapes below come from their published docs, NOT from a live
    # account, so treat the field names as unconfirmed until we've run against the sandbox. The
    # methods pass hashes straight through for that reason - a wrong guess here should be cheap.
    class Client
      BASE_URL = ENV.fetch("BIKEFLIGHTS_BASE_URL", "https://sandbox.bikeflights.com")
      EMAIL = ENV["BIKEFLIGHTS_EMAIL"]
      PASSWORD = ENV["BIKEFLIGHTS_PASSWORD"]
      STORE = ENV["BIKEFLIGHTS_STORE"]

      TOKEN_CACHE_KEY = "bike_flights_token"
      # Their docs don't state a token lifetime - one of the questions for partners@. Re-authing
      # every few hours is cheap, and an expired token surfaces as a 401 we can retry on.
      TOKEN_EXPIRY = 4.hours

      class Error < StandardError; end

      def shop_rate(params)
        post("api/ShopRate", params)
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

      def token
        Rails.cache.fetch(TOKEN_CACHE_KEY, expires_in: TOKEN_EXPIRY) do
          response = connection.post("api/Authentication/login") do |req|
            req.body = {email: EMAIL, password: PASSWORD, store: STORE}.compact
          end
          raise Error, "login failed: #{response.status} #{response.body}" unless response.success?

          body = response.body
          body.is_a?(Hash) ? (body["token"] || body["accessToken"]) : body
        end
      end

      private

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
        @connection ||= Faraday.new(url: BASE_URL) do |con|
          con.request :json
          con.response :json, content_type: /\bjson$/
          con.adapter Faraday.default_adapter
          con.options.timeout = 10
        end
      end
    end
  end
end
