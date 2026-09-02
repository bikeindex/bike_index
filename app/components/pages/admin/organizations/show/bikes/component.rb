# frozen_string_literal: true

module Pages
  module Admin
    module Organizations
      module Show
        module Bikes
          # The organization's bikes, most recent first.
          class Component < ApplicationComponent
            def initialize(organization:, bikes:, bikes_count:, sort_state:, display_dev_info: false)
              @organization = organization
              @bikes = bikes
              @bikes_count = bikes_count
              @sort_state = sort_state
              @display_dev_info = display_dev_info
            end
          end
        end
      end
    end
  end
end
