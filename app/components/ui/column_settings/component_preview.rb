# frozen_string_literal: true

module UI
  module ColumnSettings
    # Its checkboxes show and hide the table's columns and its headers drag to reorder them,
    # each remembered in localStorage
    class ComponentPreview < ApplicationComponentPreview
      def default
        {template: "ui/column_settings/component_preview/default"}
      end
    end
  end
end
