# frozen_string_literal: true

module DefinitionList::Container
  class Component < ApplicationComponent
    def initialize(multi_columns: false)
      @multi_columns = multi_columns
    end

    private

    def dl_split_classes
      return "" unless @multi_columns

      "tw:grid tw:@sm:grid-cols-2 tw:gap-x-4"
    end
  end
end
