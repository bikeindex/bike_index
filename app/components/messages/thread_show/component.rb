# frozen_string_literal: true

module Messages::ThreadShow
  class Component < ApplicationComponent
    def initialize(current_user:, marketplace_messages:, initial_message: nil, marketplace_listing: nil, can_send_message: false, new_marketplace_message: nil)
      @marketplace_messages = marketplace_messages || []

      @initial_message = initial_message || @marketplace_messages&.first
      @marketplace_listing = marketplace_listing || @initial_message&.marketplace_listing
      @current_user = current_user

      @other_user_name, @other_user_id = @initial_message&.other_user_display_and_id(@current_user)

      @can_send_message = can_send_message
      if @can_send_message
        @new_marketplace_message = new_marketplace_message ||
          MarketplaceMessage.new(marketplace_listing_id: @marketplace_listing.id, initial_record_id: @initial_message&.id)
      end
    end

    def render?
      @initial_message.present? || @marketplace_listing.present?
    end
  end
end
