# frozen_string_literal: true

module SharedBlocks
  module MainContent
    module EditBike
      # The header and edit-page menu wrapped around every bike edit template
      class Component < ApplicationComponent
        include BikeHelper

        def initialize(bike:, bike_og:, og_email:, edit_template:, edit_templates:,
          current_user:, passive_organization:)
          @bike = bike
          @bike_og = bike_og
          @og_email = og_email
          @edit_template = edit_template
          @edit_templates = edit_templates
          @current_user = current_user
          @passive_organization = passive_organization
        end

        private

        # bikes/edits leaves the submitted, unsaved value on @bike.owner_email
        def owner_email
          @og_email || @bike.owner_email
        end
      end
    end
  end
end
