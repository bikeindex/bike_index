# frozen_string_literal: true

module Messages::ThreadsIndex
  class ComponentPreview < ApplicationComponentPreview
    def default
      {
        template: "messages/threads_index/component_preview/default",
        locals: {current_user: lookbook_user, marketplace_messages:}
      }
    end

    private

    def marketplace_messages
      [
        built_marketplace_message(default_marketplace_message_attrs),
        built_marketplace_message(default_marketplace_message_attrs.merge(body: "yes")),
        built_marketplace_message(default_marketplace_message_attrs.merge(body: long_body, created_at: Time.current - 6.months))
      ]
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
        receiver: lookbook_user,
        sender: other_user,
        created_at: Time.current - 2.hours
      }
    end

    def marketplace_listing
      item = Bike.new(id: 42, year: Date.current.year - 4, mnfg_name: "Salsa", cycle_type: "bike")
      MarketplaceListing.new(id: 42, seller: lookbook_user, item:)
    end

    def built_marketplace_message(attrs)
      message = MarketplaceMessage.new(attrs)
      message.send(:set_calculated_attributes)
      message
    end

    def long_body
      "Cred poutine 8-bit, put a bird on it iceland tofu knausgaard craft beer fingerstache distillery pitchfork authentic master cleanse jawn banjo.\n\n" \
      "Mixtape distillery raw denim four loko dreamcatcher. Celiac schlitz mlkshk whatever, gochujang chia disrupt actually lomo distillery."
    end
  end
end
