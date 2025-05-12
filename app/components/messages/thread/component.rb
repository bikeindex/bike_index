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

    def item_title
      @marketplace_message.item&.title_string ||
        "#{@marketplace_message.item_type}: #{@marketplace_message.item_id}"
    end

    def message_display
      "#{@initial_record.subject} - #{@marketplace_message.body}"
    end

    def sender_display_html
      if @marketplace_message.initial_message?
        if @marketplace_message.sender_id == @current_user.id
          content_tag(:span, to_sender_text)
        else
          content_tag(:strong, @other_user_name)
        end
      else
        content_tag(:span, sender_display_html_with_count.html_safe)
      end
    end

    def sender_display_html_with_count
      messages_prior_sender_text +
        content_tag(:strong, user_display(@marketplace_message.sender_id)) +
        content_tag(:span, " #{@marketplace_message.messages_prior_count + 1}", class: "tw:opacity-65")
    end

    def messages_prior_sender_text
      # special handling for unrequited sender
      if @marketplace_message.sender_buyer? && @messages_prior_arr.all? { |kind, _| kind == "sender_buyer" }
        return to_sender_text + ((@messages_prior_arr.count > 1) ? "... " : ", ")
      end

      initial_sender_id = @messages_prior_arr.first.last
      text = user_display(initial_sender_id)
      if @messages_prior_arr.count < 2 || initial_sender_id != @marketplace_message.sender_id
        return text + ((@messages_prior_arr.count > 1) ? "... " : ", ")
      end

      # If the initial sender is the same as the final sender, always "me" - to indicate that user has replied
      "#{text}, #{me_text}" + ((@messages_prior_arr.count > 2) ? "... " : ", ")
    end

    def to_sender_text
      "#{translation(".to")}: #{@other_user_name}"
    end

    def me_text
      translation(".me")
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
