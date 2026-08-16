# frozen_string_literal: true

module UI
  module Forms
    module NestedFields
      module PreviewFields
        # One record's fields for the UI::Forms::NestedFields preview - the smallest thing that
        # satisfies its wrapper contract, and the reference for what a fields_component owes it
        class Component < ApplicationComponent
          def initialize(form_builder:)
            @form_builder = form_builder
          end
        end
      end
    end
  end
end
