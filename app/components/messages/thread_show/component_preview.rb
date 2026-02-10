# frozen_string_literal: true

module Messages::ThreadShow
  class ComponentPreview < ApplicationComponentPreview
    # @display legacy_stylesheet true
    # @param message_id text "Message ID to view (only works in dev)"
    def buyer(message_id: nil)
      marketplace_messages = if Rails.env.development? && message_id.present?
        current_user, marketplace_messages = user_and_marketplace_messages_for(:buyer, message_id)
        marketplace_messages
      else
        current_user = lookbook_user
        mocked_marketplace_messages(item_owner: :other_user)
      end

      render(Messages::ThreadShow::Component.new(current_user:, marketplace_messages:, can_send_message: true))
    end

    # @display legacy_stylesheet true
    # @param message_id text "Message ID to view (only works in dev)"
    def seller(message_id: nil)
      marketplace_messages = if Rails.env.development? && message_id.present?
        current_user, marketplace_messages = user_and_marketplace_messages_for(:seller, message_id)
        marketplace_messages
      else
        current_user = lookbook_user
        mocked_marketplace_messages(item_owner: :lookbook_user, is_initial_message: true)
      end

      render(Messages::ThreadShow::Component.new(current_user:, marketplace_messages:, can_send_message: true))
    end

    private

    def other_user
      return @other_user if defined?(@other_user)

      @other_user = User.find_by_email("contact@bikeindex.org") ||
        User.new(name: "John Smith", username: "some-username", id: 42)
    end

    def mocked_marketplace_messages(item_owner: :other_user, is_initial_message: false, sender: nil)
      marketplace_listing = marketplace_listing((item_owner == :other_user) ? other_user : lookbook_user)
      initial_sender = (item_owner == :other_user) ? lookbook_user : other_user

      initial_record = build_marketplace_message(id: 42, marketplace_listing:, sender: initial_sender,
        body: "When are you available? Can I come by to pick it up sometime this week?",
        created_at: Time.current - 1.hour)

      return [initial_record] if is_initial_message
      sender ||= (item_owner == :other_user) ? other_user : lookbook_user
      [
        initial_record,
        build_marketplace_message(id: 43, marketplace_listing:, initial_record:, messages_prior_count: 1, sender:)
      ]
    end

    def build_marketplace_message(id:, marketplace_listing:, sender:, initial_record: nil, body: nil, messages_prior_count: 0, created_at: nil)
      body ||= "I'm available tuesday evening"
      created_at ||= Time.current - 1.minute
      receiver = (sender.id == lookbook_user.id) ? other_user : lookbook_user

      message = MarketplaceMessage.new(
        id:,
        messages_prior_count:,
        subject: "I'm interested in buying this bike",
        body:,
        initial_record:,
        marketplace_listing:,
        receiver:,
        sender:,
        created_at:
      )
      message.send(:set_calculated_attributes)
      message
    end

    def marketplace_listing(seller)
      MarketplaceListing.new(id: 42, seller:, item:,
        condition: :excellent, amount_cents: 10_000, status: :for_sale,
        published_at: Time.current - 1.day)
    end

    def user_and_marketplace_messages_for(user_target, message_id)
      marketplace_message = MarketplaceMessage.find(message_id)
      messages = if marketplace_message.initial_message?
        [marketplace_message]
      else
        MarketplaceMessage.where(initial_record_id: marketplace_message.initial_record_id)
          .where("id <= ?", marketplace_message.id).order(:id)
      end

      [
        (user_target == :seller) ? messages.first.receiver : messages.first.sender,
        messages
      ]
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
