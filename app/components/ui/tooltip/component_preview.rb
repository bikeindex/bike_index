# frozen_string_literal: true

module UI::Tooltip
  class ComponentPreview < ApplicationComponentPreview
    # @!group Variants
    def multiple
      render_with_template(template: "ui/tooltip/preview/multiple")
    end
    # @!endgroup
  end
end
