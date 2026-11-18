# frozen_string_literal: true

module Pages
  module Shop
    module Index
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Shop::Index::Component.new)
        end
      end
    end
  end
end
