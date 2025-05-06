# frozen_string_literal: true

module DefinitionList::Container
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(DefinitionList::Container::Component.new())
    end
  end
end
