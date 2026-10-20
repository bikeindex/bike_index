# frozen_string_literal: true

module Pages
  module Org
    module ParkingNotificationLocation
      # Where a parking notification happened - a pin on a map, or an address typed in.
      # Rendered into a form under the `org--parking-notification-form` controller,
      # which drives it
      class Component < ApplicationComponent
        def initialize(form:)
          @form = form
        end
      end
    end
  end
end
