# frozen_string_literal: true

module Search::BikeBox
  class ComponentPreview < ApplicationComponentPreview
    def default
      bike = Bike.find(2677107)
      current_user = User.find(85)
      render(Search::BikeBox::Component.new(bike:, current_user:))
    end
  end
end
