# frozen_string_literal: true

module DefinitionList::Container
  class Component < ApplicationComponent
    def initialize(multi_columns: false)
      @multi_columns = multi_columns
    end
  end
end
