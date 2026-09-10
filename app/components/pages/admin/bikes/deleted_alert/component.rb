# frozen_string_literal: true

module Pages
  module Admin
    module Bikes
      module DeletedAlert
        # Says a bike is deleted on a screen that isn't scoped to it - an index filtered by
        # search_bike_id, say. The screens that are scoped to one bike say it through
        # Pages::Admin::Bikes::Tabs' alert slot instead.
        class Component < ApplicationComponent
          def initialize(bike:)
            @bike = bike
          end

          def render? = @bike&.deleted?
        end
      end
    end
  end
end
