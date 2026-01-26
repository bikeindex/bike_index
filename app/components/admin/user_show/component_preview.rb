# frozen_string_literal: true

module Admin::UserShow
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Admin::UserShow::Component.new(user:, bikes:, bikes_count:))
    end
  end
end
