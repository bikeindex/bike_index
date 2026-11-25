# frozen_string_literal: true

module SharedBlocks
  module UserAlerts
    module BikeListModal
      # The chrome the alerts that interrupt share: a modal opened on page load, listing
      # the registrations that need something, between a lead and a de-emphasized footer
      class Component < ApplicationComponent
        def initialize(id:, title:, intro:, footer:)
          @id = id
          @title = title
          @intro = intro
          @footer = footer
        end
      end
    end
  end
end
