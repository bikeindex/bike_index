# frozen_string_literal: true

module DefinitionList::Row
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(DefinitionList::Row::Component.new(label:, value:))
    end
  end
end
