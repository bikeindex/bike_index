# frozen_string_literal: true

module Org::BikeAccessPanel
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Org::BikeAccessPanel::Component.new(bike:, organization:, current_user:))
    end
  end
end
