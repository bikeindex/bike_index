# frozen_string_literal: true

module Messages::Thread
  class ComponentPreview < ApplicationComponentPreview
    def default
      # marketplace_message_1 = built_marketplace_message(default_marketplace_message_attrs)
      # marketplace_message_2 = built_marketplace_message(default_marketplace_message_attrs.merge(body: "yes"))
      # # marketplace_message_3 = built_marketplace_message(default_marketplace_message_attrs.merge(messages_prior_count: 3))
      # render do
      #   Messages::Thread::Component.new(marketplace_message: marketplace_message_1, current_user:))
      #   Messages::Thread::Component.new(marketplace_message: marketplace_message_2, current_user:))
      # end
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
        created_at: Time.current - 2.hours - 6.months
      }
    end

    def marketplace_listing
      item = Bike.new(id: 42, year: Date.current.year - 4, mnfg_name: "Salsa", cycle_type: "bike")
      MarketplaceListing.new(id: 42, seller: current_user, item:)
    end

    def built_marketplace_message(attrs)
      message = MarketplaceMessage.new(attrs)
      message.send(:set_calculated_attributes)
      message
    end
  end
end
