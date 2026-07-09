# frozen_string_literal: true

module UI
  module ColorSwatch
    class ComponentPreview < ApplicationComponentPreview
      # Every registration color on one page — the cover-up color renders its blend
      def all_colors
        {template: "ui/color_swatch/component_preview/all_colors", locals: {colors: Color.commonness}}
      end
    end
  end
end
