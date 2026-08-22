# frozen_string_literal: true

module Admin
  module Bikes
    module Header
      # Everything above the body on an admin screen scoped to one bike: the tab row, and
      # the summary of the registration under it. Every such screen renders this, so the
      # nil-bike case lives here rather than in each of them - admin screens reach their
      # bike through a soft-deleted association, which can come back empty.
      class Component < ApplicationComponent
        def initialize(bike:, active:, user: nil, stolen_record: nil, display_recovery: false,
          display_dev_info: false)
          @bike = bike
          @active = active
          @user = user
          @stolen_record = stolen_record || bike&.fetch_current_stolen_record
          @display_recovery = display_recovery || @stolen_record&.recovered?
          @display_dev_info = display_dev_info
        end
      end
    end
  end
end
