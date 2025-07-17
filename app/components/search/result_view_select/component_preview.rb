# frozen_string_literal: true

module Search::ResultViewSelect
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Search::ResultViewSelect::Component.new)
    end
  end
end
