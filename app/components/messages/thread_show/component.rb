# frozen_string_literal: true

module Messages::ThreadShow
  class Component < ApplicationComponent
    def initialize(current_user:, marketplace_messages:, initial_message: nil, marketplace_listing: nil)
      @marketplace_messages = marketplace_messages
      @initial_message = initial_message || @marketplace_messages.first
      @marketplace_listing = marketplace_listing || @initial_message.marketplace_listing
      @current_user = current_user

      @other_user_name, @other_user_id = @initial_message.other_user_display_and_id(@current_user)
    end

    private

    def user_display(user_id)
      if user_id == @current_user.id
        @current_user.marketplace_message_name
      else
        @other_user_name
      end
    end
  end
end
