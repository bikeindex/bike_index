# frozen_string_literal: true

module Messages::ThreadShow
  class Component < ApplicationComponent
    def initialize(
      current_user:,
      marketplace_messages:,
      initial_message: nil,
      marketplace_listing: nil,
      can_send_message: false,
      new_marketplace_message: nil
    )
      @marketplace_messages = marketplace_messages || []

      @initial_message = initial_message || @marketplace_messages&.first
      @marketplace_listing = marketplace_listing || @initial_message&.marketplace_listing
      @sale = @marketplace_listing.sale
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

    private

    def new_thread?
      @initial_message.blank?
    end

    def current_user_seller?
      return false if @initial_message.blank?

      @initial_message.receiver_id == @current_user.id
    end

    def user_banned?
      return false if @initial_message.blank?

      @initial_message.sender&.banned? || @initial_message.receiver&.banned?
    end

    def user_deleted?
      return false if @initial_message.blank?

      @initial_message.sender.blank? || @initial_message.receiver&.blank?
    end

    def show_mark_sold?
      return false if new_thread?

      current_user_seller? && @marketplace_listing.current?
    end

    def sold_alert_rendered?
      @sold_alert_rendered
    end

    def render_sold_alert
      @sold_alert_rendered = true
      render(UI::Alert::Component.new(kind: :notice, margin_classes: "tw:my-8")) { sold_alert_content }
    end

    def item_type_display
      @marketplace_listing.item_type_display.downcase
    end

    def sold_alert_content
      content_tag(:span) do
        if current_user_seller?
          buyer = if @sale.buyer&.id == @other_user_id
            "#{@other_user_name} (this message)"
          else
            "another user (#{@sale.buyer_name})"
          end
          concat(content_tag(:span, "You marked this #{item_type_display} sold to #{buyer} "))
        else
          concat(content_tag(:span, "This #{item_type_display} was sold "))
        end
        concat(content_tag(:span, l(@sale.created_at, format: :convert_time), class: "localizeTime withPreposition"))
      end
    end
  end
end
