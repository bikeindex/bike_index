# frozen_string_literal: true

module Integrations
  module Shopify
    module Client
      extend Functionable

      # New apps are GraphQL only - Shopify froze REST for App Store submissions in 2025
      API_VERSION = ENV.fetch("SHOPIFY_API_VERSION", "2026-07")
      SHOPIFY_KEY = ENV["SHOPIFY_API_KEY"]
      SHOPIFY_SECRET = ENV["SHOPIFY_API_SECRET"]
      DEFAULT_SCOPE = "read_orders,read_customers"
      # orders/updated too: a line item property is fixed at add-to-cart, so a serial
      # remembered after the sale can only arrive as an edit to the order note
      WEBHOOK_TOPICS = %w[ORDERS_CREATE ORDERS_UPDATED APP_UNINSTALLED].freeze
      ENABLED = (SHOPIFY_KEY.present? && SHOPIFY_SECRET.present?).freeze

      def authorization_url(shop_domain:, state:)
        params = {
          client_id: SHOPIFY_KEY,
          scope: DEFAULT_SCOPE,
          redirect_uri: Rails.application.routes.url_helpers.callback_shopify_integration_url,
          state:
        }
        "https://#{shop_domain}/admin/oauth/authorize?#{params.to_query}"
      end

      def exchange_token(shop_domain:, code:)
        resp = oauth_connection(shop_domain).post("admin/oauth/access_token") do |req|
          req.body = {client_id: SHOPIFY_KEY, client_secret: SHOPIFY_SECRET, code:}
        end
        resp.success? ? resp.body : nil
      end

      # The OAuth callback signs its query params; webhooks sign their raw body
      def verified_callback?(params)
        hmac = params[:hmac]
        return false if hmac.blank? || !ENABLED

        # Unsafe because the signature is computed over whatever Shopify sent, not assigned
        message = params.except(:hmac, :signature, :controller, :action)
          .to_unsafe_h.sort.map { |k, v| "#{k}=#{v}" }.join("&")
        Binxtils::Secure.compare?(hmac, OpenSSL::HMAC.hexdigest("sha256", SHOPIFY_SECRET, message))
      end

      def verified_webhook?(raw_body, hmac_header)
        return false if hmac_header.blank? || !ENABLED

        digest = OpenSSL::HMAC.digest("sha256", SHOPIFY_SECRET, raw_body.to_s)
        Binxtils::Secure.compare?(hmac_header, Base64.strict_encode64(digest))
      end

      def fetch_shop(shopify_integration)
        query(shopify_integration, <<~GRAPHQL)
          { shop { name myshopifyDomain } }
        GRAPHQL
      end

      def register_webhooks(shopify_integration)
        callback_url = Rails.application.routes.url_helpers.shopify_webhooks_url
        WEBHOOK_TOPICS.map { register_webhook(shopify_integration, it, callback_url) }
      end

      #
      # private below here
      #

      def register_webhook(shopify_integration, topic, callback_url)
        query(shopify_integration, <<~GRAPHQL, topic:, callbackUrl: callback_url)
          mutation($topic: WebhookSubscriptionTopic!, $callbackUrl: URL!) {
            webhookSubscriptionCreate(
              topic: $topic
              webhookSubscription: {callbackUrl: $callbackUrl, format: JSON}
            ) { userErrors { field message } webhookSubscription { id } }
          }
        GRAPHQL
      end

      def query(shopify_integration, graphql, **variables)
        api_connection(shopify_integration).post("admin/api/#{API_VERSION}/graphql.json") do |req|
          req.body = {query: graphql, variables:}
        end
      end

      def api_connection(shopify_integration)
        Faraday.new(url: "https://#{shopify_integration.shop_domain}") do |conn|
          conn.request :json
          conn.response :json, content_type: /\bjson$/
          conn.adapter Faraday.default_adapter
          conn.headers["X-Shopify-Access-Token"] = shopify_integration.access_token
          conn.options.timeout = 30
        end
      end

      def oauth_connection(shop_domain)
        Faraday.new(url: "https://#{shop_domain}") do |conn|
          conn.request :json
          conn.response :json, content_type: /\bjson$/
          conn.adapter Faraday.default_adapter
          conn.options.timeout = 15
        end
      end

      conceal :register_webhook, :query, :api_connection, :oauth_connection
    end
  end
end
