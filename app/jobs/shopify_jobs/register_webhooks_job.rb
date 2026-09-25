# frozen_string_literal: true

module ShopifyJobs
  class RegisterWebhooksJob < ApplicationJob
    sidekiq_options queue: "high_priority", retry: 3

    def perform(shopify_integration_id)
      shopify_integration = ShopifyIntegration.find_by(id: shopify_integration_id)
      return if shopify_integration.blank? || skip_job?

      errors = user_errors(Integrations::Shopify::Client.register_webhooks(shopify_integration))
      return shopify_integration.record_error(errors.join(", ")) if errors.any?

      shop = Integrations::Shopify::Client.fetch_shop(shopify_integration)
      shopify_integration.update(status: :active, webhooks_registered_at: Time.current,
        shop_data: shop.success? ? shop.body.dig("data", "shop") : nil)
    end

    private

    # A GraphQL mutation reports a rejected subscription in userErrors with a 200 status, and
    # each topic answers under its own alias
    def user_errors(response)
      return ["#{response.status} from Shopify"] unless response.success?

      (response.body["data"] || {}).values.flat_map { it["userErrors"] || [] }.map { it["message"] } +
        (response.body["errors"] || []).map { it["message"] }
    end
  end
end
