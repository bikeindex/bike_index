# frozen_string_literal: true

module Messages::Threads
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Messages::Threads::Component.new(marketplace_messages:, current_user:))
    end

    private
  end
end
