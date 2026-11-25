# frozen_string_literal: true

module Pages
  module Messages
    module ForSaleItem
      class Component < ApplicationComponent
        def initialize(current_user: nil, vehicle: nil, vehicle_id: nil, marketplace_listing: nil)
          @current_user = current_user
          @vehicle = vehicle
          @vehicle ||= Bike.unscoped.find_by_id(vehicle_id) if vehicle_id.present?
          @marketplace_listing = marketplace_listing
        end
      end
    end
  end
end
