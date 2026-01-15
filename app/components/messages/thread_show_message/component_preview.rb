# frozen_string_literal: true

module Messages::ThreadShowMessage
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Messages::ThreadShowMessage::Component.new(marketplace_message:, initial_message:, current_user:))
    end
  end
end
