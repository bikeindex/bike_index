# frozen_string_literal: true

module HeaderTags
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(HeaderTags::Component.new(page_title:, page_obj:, controller_name:, controller_namespace:, action_name:))
    end
  end
end
