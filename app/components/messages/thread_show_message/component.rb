# frozen_string_literal: true

module Messages::ThreadShowMessage
  class Component < ApplicationComponent
    def initialize(marketplace_message:, initial_message:, current_user:, other_user_name: nil, other_user_id: nil)
      @marketplace_message = marketplace_message
      @initial_message = initial_message
      @current_user = current_user

      # other_user_id and other_user_name should be passed in!
      @other_user_name, @other_user_id = if other_user_id.present?
        [other_user_name, other_user_id]
      else
        @initial_message&.other_user_display_and_id(@current_user)
      end
    end

    private

    def currently_buyer?
      @initial_message.sender_id == @current_user.id
    end

    def initial_message?
      @marketplace_message.id == @initial_message.id
    end

    def user_display(user_id, parens: false)
      str = if user_id == @current_user.id
        @current_user.marketplace_message_name
      else
        @other_user_name
      end
      parens ? "(#{str})" : str
    end

    # make sent messages align right, received left
    def margin_class
      # return "" if initial_message?

      if @current_user.id == @marketplace_message.sender_id
        "tw:ml-4 tw:lg:ml-8"
      else
        "tw:mr-4 tw:lg:mr-8"
      end
    end

    def receiver_display
      if @marketplace_message.receiver_id == @current_user.id
        translation(".me")
      else
        @other_user_name
      end
    end
  end
end
