# frozen_string_literal: true

module Messages::ThreadShow
  class ComponentPreview < ApplicationComponentPreview
    # @display legacy_stylesheet true
    def buyer
      @item_owner = :other_user
      marketplace_message = built_marketplace_message(marketplace_message_attrs)

      render(Messages::ThreadShow::Component.new(current_user: lookbook_user,
        marketplace_messages: [marketplace_message]))
    end

    # @display legacy_stylesheet true
    def seller
      @item_owner = :lookbook_user
      marketplace_message = built_marketplace_message(marketplace_message_attrs)

      render(Messages::ThreadShow::Component.new(current_user: other_user,
        marketplace_messages: [marketplace_message]))
    end

    private

    def other_user
      return @other_user if defined?(@other_user)

      @other_user = User.find_by_email("contact@bikeindex.org") ||
        User.new(name: "John Smith", username: "some-username", id: 42)
    end

    def marketplace_message_attrs(receiver: lookbook_user, sender: other_user)
      sender_val = (@item_owner == :other_user) ? lookbook_user : other_user
      # The initial record always needs to be
      (@item_owner == :other_user) ? other_user : lookbook_user
      {
        id: 42,
        messages_prior_count: 0,
        subject: "I'm interested in buying this bike",
        body: "When are you available? Can I come by to pick it up sometime this week?",
        initial_record_id: MarketplaceMessage.new(id: 42, sender: sender_val, marketplace_listing:),
        marketplace_listing:,
        receiver:,
        sender:,
        created_at: Time.current - 2.hours - 6.months
      }
    end

    def marketplace_listing
      return @marketplace_listing if defined? @marketplace_listing
      seller_val = (@item_owner == :other_user) ? other_user : lookbook_user

      @marketplace_listing = MarketplaceListing.new(id: 42, seller: seller_val, item:,
        condition: :excellent, amount_cents: 10_000, status: :for_sale,
        published_at: Time.current - 1.day)
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
