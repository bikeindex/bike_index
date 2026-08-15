# frozen_string_literal: true

module PageBlock
  module Skeletons
    module EditBike
      # The header and edit-page menu wrapped around every bike edit template
      class Component < ApplicationComponent
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
      end
    end
  end
end
