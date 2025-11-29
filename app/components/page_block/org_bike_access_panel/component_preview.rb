# frozen_string_literal: true

module PageBlock::OrgBikeAccessPanel
  class ComponentPreview < ApplicationComponentPreview
    # @display legacy_stylesheet true
    def default
      # TODO: render something - without personal info
      organization = Organization.friendly_find("hogwarts")
      bike = nil
      current_user = nil
      render(PageBlock::OrgBikeAccessPanel::Component.new(bike:, organization:, current_user:))
    end
  end
end
