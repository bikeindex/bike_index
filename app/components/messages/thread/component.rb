# frozen_string_literal: true

module Messages::Thread
  class Component < ApplicationComponent
    def initialize(marketplace_message:, current_user:)
      @marketplace_message = marketplace_message
      @initial_record = @marketplace_message.initial_record
      @current_user = current_user
      # pp @marketplace_message, @current_user
      # result = @marketplace_message.other_user(@current_user.id)
      # pp result
      @other_user, @other_user_kind = @marketplace_message.other_user(@current_user)
      # pp @other_user&.id, @other_user_kind
    end

    private

    def item_title
      @marketplace_message.item&.title_string ||
        "#{@marketplace_message.item_type}: #{@marketplace_message.item_id}"
    end

    def message_display
      "#{@initial_record.subject} - #{@marketplace_message.body}"
    end

    def user_display(user_id)
      if user_id == @current_user
        translation(".me")
      else
        @other_user.marketplace_message_name
      end
    end

    def sender_display_html
      user_display(@marketplace_message.initial_record.sender_id)
    end
  end
end
