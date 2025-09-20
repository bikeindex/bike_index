# frozen_string_literal: true

module Messages::ThreadShow
  class ComponentPreview < ApplicationComponentPreview
    def default
      marketplace_message = built_marketplace_message(default_marketplace_message_attrs)
      render(Messages::ThreadShow::Component.new(current_user:, marketplace_messages: [marketplace_message]))
    end

    private

    def current_user
      @current_user ||= User.find(ENV.fetch("LOOKBOOK_USER_ID", 1))
    end

    def other_user
      User.new(name: "John Smith", username: "some-username", id: 42)
    end

    def default_marketplace_message_attrs
      {
        id: 42,
        messages_prior_count: 0,
        subject: "I'm interested in buying this bike",
        body: "When are you available? Can I come by to pick it up sometime this week?",
        initial_record_id: 42,
        marketplace_listing: marketplace_listing,
        receiver: current_user,
        sender: other_user,
        created_at: 2.hours.ago - 6.months
      }
    end

    def marketplace_listing
      MarketplaceListing.new(id: 42, seller: current_user, item:, condition: :excellent,
        amount_cents: 1_000, status: :for_sale)
    end

    def built_marketplace_message(attrs)
      message = MarketplaceMessage.new(attrs)
      message.send(:set_calculated_attributes)
      message
    end

    def item
      Bike.new(
        id: 35,
        serial_number: "XXX999",
        mnfg_name: "Humble Frameworks",
        year: "2015",
        primary_frame_color_id: Color.where(name: "Purple").first_or_create,
        frame_model: "self titled",
        frame_material: :steel,
        cycle_type: :bike,
        is_for_sale: true,
        thumb_path: "https://files.bikeindex.org/uploads/Pu/395980/small_D3C6B1AF-F1FC-4BAA-BD39-9C107871FCAE.jpeg"
      )
    end
  end
end
