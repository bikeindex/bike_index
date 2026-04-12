# frozen_string_literal: true

module PageBlock::ForSchoolsTop
  class ComponentPreview < ApplicationComponentPreview
    # @display kelsey_stylesheet true
    def default
      render(PageBlock::ForSchoolsTop::Component.new)
    end
  end
end
