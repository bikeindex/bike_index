# frozen_string_literal: true

module ShopifyJobs
  class RegisterWebhooksJob < ApplicationJob
    sidekiq_options queue: "high_priority", retry: 3

    def perform(shopify_integration_id)
      shopify_integration = ShopifyIntegration.find_by(id: shopify_integration_id)
      return if shopify_integration.blank? || skip_job?

      responses = Integrations::Shopify::Client.register_webhooks(shopify_integration)
      errors = responses.flat_map { user_errors(it) }
      if errors.any?
        shopify_integration.record_error(errors.join(", "))
      else
        shopify_integration.update(status: :active, webhooks_registered_at: Time.current)
        Integrations::Shopify::Client.fetch_shop(shopify_integration).then do |resp|
          shopify_integration.update(shop_data: resp.body.dig("data", "shop")) if resp.success?
        end
      end
    end

    private

    # A GraphQL mutation reports a rejected subscription in userErrors with a 200 status
    def user_errors(response)
      return ["#{response.status} from Shopify"] unless response.success?

      (response.body.dig("data", "webhookSubscriptionCreate", "userErrors") || [])
        .map { it["message"] } + (response.body["errors"] || []).map { it["message"] }
    end
  end
end
