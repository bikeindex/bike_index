# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module LegacyViewLink
        # The redesign's view-preference control: an opt-out to the classic bike show,
        # or — for viewers who already switched to legacy but reached this page anyway —
        # a plain link there. ToggleView is its counterpart on the legacy page.
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
