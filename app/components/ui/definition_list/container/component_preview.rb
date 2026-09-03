# frozen_string_literal: true

module UI
  module DefinitionList
    module Container
      class ComponentPreview < ApplicationComponentPreview
        # @!group Terms
        def default
          {template: "ui/definition_list/container/component_preview/default", locals: {multi_columns: false}}
        end

        def multi_columns_true
          {template: "ui/definition_list/container/component_preview/default", locals: {multi_columns: true}}
        end

        def right_align
          {template: "ui/definition_list/container/component_preview/default", locals: {term: :right_align}}
        end

        def below
          {template: "ui/definition_list/container/component_preview/default", locals: {term: :below}}
        end
        # @!endgroup
      end
    end
  end
end
