# frozen_string_literal: true

module Pages
  module Bikes
    module StolenReport
      module PhotoShot
        # One of the photo step's two shots: what to take, an example, and the tile it's uploaded from.
        # stolen-report--photo stores a pick on the bike right away, rather than with the report
        class Component < ApplicationComponent
          KINDS = %i[drive_side unique_marks].freeze

          def initialize(bike:, kind:, title:, hint:, badge:, badge_color:, public_image: nil)
            @bike = bike
            @kind = KINDS.include?(kind) ? kind : KINDS.first
            @title = title
            @hint = hint
            @badge = badge
            @badge_color = badge_color
            @public_image = public_image
          end

          private

          def example_text
            (@kind == :drive_side) ? translation(".example_drive_side") : translation(".example_unique_marks")
          end
        end
      end
    end
  end
end
