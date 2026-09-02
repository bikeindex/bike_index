# frozen_string_literal: true

module Pages
  module Search
    module ResultViewSelect
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Search::ResultViewSelect::Component.new)
        end
      end
    end
  end
end
