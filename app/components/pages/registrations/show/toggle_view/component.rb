# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module ToggleView
        # The view-preference banner atop the legacy bike show page, inviting the viewer
        # to the redesign. LegacyViewLink is its counterpart on the redesign.
        class Component < ApplicationComponent
          def initialize(bike:, show_legacy:)
            @bike = bike
            @show_legacy = show_legacy
          end
        end
      end
    end
  end
end
