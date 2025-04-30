# frozen_string_literal: true

module LegacyFormWell::FormGroupRow
  class Component < ApplicationComponent
    def initialize(form_builder:, label:, label_translation: nil, row_classes: "form-group row")
      @form_builder = form_builder
      @label = label
      @label_translation = label_translation
      @row_classes = (row_classes || "") + " form-group row"
    end
  end
end
