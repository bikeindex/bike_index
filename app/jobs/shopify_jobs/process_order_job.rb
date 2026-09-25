# frozen_string_literal: true

module ShopifyJobs
  class ProcessOrderJob < ApplicationJob
    sidekiq_options queue: "high_priority", retry: 3

    def perform(shopify_integration_id, order)
      shopify_integration = ShopifyIntegration.find_by(id: shopify_integration_id)
      return if shopify_integration.blank? || skip_job?
      return unless Integrations::Shopify::OrderParser.registerable?(order)

      registrations = Integrations::Shopify::OrderParser.registrations(order)
      return if registrations.none?

      registrations.each { register_bike(shopify_integration, order, it) }
      shopify_integration.record_order
    end

    private

    def register_bike(shopify_integration, order, registration)
      b_param = BParam.create(creator_id: shopify_integration.organization.auto_user_id,
        params: b_param_hash(shopify_integration, order, registration),
        origin: "shopify_webhook")
      BikeServices::Creator.new.create_bike(b_param)
    end

    def b_param_hash(shopify_integration, order, registration)
      {
        bike: {
          pos_kind: "shopify_pos",
          is_new: true,
          # orders/updated redelivers the whole sale, so every registration is a repeat of
          # one already made - the duplicate check is what keeps it from registering twice
          no_duplicate: true,
          manufacturer_id: registration.manufacturer,
          frame_model: registration.frame_model,
          serial_number: registration.serial,
          owner_email: Integrations::Shopify::OrderParser.owner_email(order),
          user_name: order.dig("customer", "first_name").present? ?
            "#{order.dig("customer", "first_name")} #{order.dig("customer", "last_name")}".strip : nil,
          color: "Black", # Shopify carries no frame color, and a color is required
          send_email: true,
          creation_organization_id: shopify_integration.organization_id
        }
      }
    end
  end
end
