# frozen_string_literal: true

# NOTE: This component makes a number of DB calls - so rendering of this should be cached!
module Messages::Thread
  class Component < ApplicationComponent
    def initialize(marketplace_message:, current_user:)
      @marketplace_message = marketplace_message
      @messages_prior_arr = @marketplace_message.messages_prior.pluck(:kind, :sender_id)
      @initial_record = @marketplace_message.initial_record
      @current_user = current_user

      @other_user_name, @other_user_id = @marketplace_message.other_user_display_and_id(@current_user)
    end

    private

    def message_path
      new_my_account_message_path(marketplace_listing_id: @initial_record.marketplace_listing_id,
        initial_record_id: @initial_record.id)
    end

    def item_title
      @marketplace_message.item&.title_string ||
        "#{@marketplace_message.item_type}: #{@marketplace_message.item_id}"
    end

    def message_display
      if @marketplace_message.initial_message?
        "#{@initial_record.subject} - #{@marketplace_message.body}".truncate(100)
      else
        @marketplace_message.body.truncate(100)
      end
    end

    def sender_display_html
      if @marketplace_message.initial_message?
        if @marketplace_message.sender_id == @current_user.id
          content_tag(:span, to_sender_text)
        else
          content_tag(:strong, @other_user_name, class: "tw:font-bold")
        end
      else
        content_tag(:span, (messages_prior_sender_text +
          content_tag(:strong, user_display(@marketplace_message.sender_id), class: "tw:font-bold") +
          content_tag(:span, " #{@marketplace_message.messages_prior_count + 1}", class: "tw:opacity-65")).html_safe)
      end
    end

    def sender_full_text
      (@messages_prior_arr.map { |_, id| user_display(user_id) } +
        [user_display(@marketplace_message.sender_id)])
        .join(", ")
    end

    def messages_prior_sender_text
      # special handling for unrequited sender
      if @marketplace_message.sender_buyer? && @messages_prior_arr.all? { |kind, _| kind == "sender_buyer" }
        return to_sender_text + ((@messages_prior_arr.count > 1) ? "... " : ", ")
      end

      initial_sender_id = @messages_prior_arr.first.last
      text = user_display(initial_sender_id)

      # If the initial sender is the same as the final sender, always include the other user display
      # - to indicate that user has replied
      if @messages_prior_arr.count > 1 && initial_sender_id == @marketplace_message.sender_id
        "#{text}, #{user_display(@marketplace_message.receiver_id)}" +
          ((@messages_prior_arr.count > 2) ? "... " : ", ")
      else
        text + ((@messages_prior_arr.count > 1) ? "... " : ", ")
      end
    end

    def to_sender_text
      "#{translation(".to")}: #{@other_user_name}"
    end

    def user_display(user_id)
      if user_id == @current_user.id
        translation(".me")
      else
        @other_user_name
      end
    end
  end
end
