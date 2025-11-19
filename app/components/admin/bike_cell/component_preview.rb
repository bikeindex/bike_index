# frozen_string_literal: true

module Admin::BikeCell
  class ComponentPreview < ApplicationComponentPreview
    # @group Bike Variants
    def with_bike
      render(Admin::BikeCell::Component.new(bike:))
    end

    def with_bike_and_link
      render(Admin::BikeCell::Component.new(bike:, bike_link_path: admin_bike_path(bike.id)))
    end

    def with_bike_id_only
      render(Admin::BikeCell::Component.new(bike_id: bike.id))
    end

    def missing_bike
      render(Admin::BikeCell::Component.new(bike_id: 99999999))
    end

    def with_search_link
      render(Admin::BikeCell::Component.new(
        bike:,
        render_search: true,
        search_url: admin_bikes_path(search_bike_id: bike.id)
      ))
    end

    private

    def bike
      Bike.find(35)
    end
  end
end
