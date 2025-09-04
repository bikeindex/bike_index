# frozen_string_literal: true

module Org::BikeAccessPanel
  class ComponentPreview < ApplicationComponentPreview
    # @display legacy_stylesheet true
    def default
      # TODO: render something without personal info
      organization = Organization.friendly_find("hogwarts")
      bike = Bike.last
      current_user = nil
      render(Org::BikeAccessPanel::Component.new(bike:, organization:, current_user:))
    end
  end
end
