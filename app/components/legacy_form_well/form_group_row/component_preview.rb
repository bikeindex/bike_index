# frozen_string_literal: true

module LegacyFormWell::FormGroupRow
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(LegacyFormWell::FormGroupRow::Component.new(form_builder:, label:, label_translation:, row_classes:))
    end
  end
end
