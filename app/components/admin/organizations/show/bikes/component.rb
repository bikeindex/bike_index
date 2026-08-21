# frozen_string_literal: true

module Admin
  module Organizations
    module Show
      module Bikes
        # The organization's bikes, most recent first.
        class Component < ApplicationComponent
          def initialize(organization:, bikes:, bikes_count:)
            @organization = organization
            @bikes = bikes
            @bikes_count = bikes_count
          end
        end
      end
    end
  end
end
