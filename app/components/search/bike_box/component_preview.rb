# frozen_string_literal: true

module Search::BikeBox
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Search::BikeBox::Component.new(bike:, current_user:))
    end
  end
end
