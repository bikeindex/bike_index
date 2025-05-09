# frozen_string_literal: true

module DefinitionList::Container
  class ComponentPreview < ApplicationComponentPreview
    # @!group Multi Column
    def multi_columns_false(multi_columns: false)
      {template: "definition_list/container/component_preview/default", locals: {multi_columns:}}
    end

    def multi_columns_true(multi_columns: true)
      {template: "definition_list/container/component_preview/default", locals: {multi_columns:}}
    end
    # @!endgroup
  end
end
