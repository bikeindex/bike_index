# frozen_string_literal: true

module DefinitionList::Row
  class Component < ApplicationComponent
    def initialize(label:, value:)
      @label = label
    @value = value
    end
  end
end
