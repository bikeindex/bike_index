# frozen_string_literal: true

module UI::DefinitionList::Container
  class ComponentPreview < ApplicationComponentPreview
    # @!group Multi Column
    def default
      {template: "ui/definition_list/container/component_preview/default", locals: {multi_columns: false}}
    end

    def multi_columns_true
      {template: "ui/definition_list/container/component_preview/default", locals: {multi_columns: true}}
    end
    # @!endgroup
  end
end
