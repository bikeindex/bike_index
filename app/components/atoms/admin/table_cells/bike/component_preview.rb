# frozen_string_literal: true

module Atoms
  module Admin
    module TableCells
      module Bike
        class ComponentPreview < ApplicationComponentPreview
          # @!group Bike Variants
          def with_bike
            render(Atoms::Admin::TableCells::Bike::Component.new(bike:))
          end

          def with_bike_and_link
            render(Atoms::Admin::TableCells::Bike::Component.new(bike:, bike_link_path: admin_bike_path(bike.id)))
          end

          def with_bike_id_only
            render(Atoms::Admin::TableCells::Bike::Component.new(bike_id: bike.id))
          end

          def missing_bike
            render(Atoms::Admin::TableCells::Bike::Component.new(bike_id: 99999999))
          end

          def deleted_bike
            render(Atoms::Admin::TableCells::Bike::Component.new(bike_id: 195))
          end

          def with_search_link
            render(Atoms::Admin::TableCells::Bike::Component.new(
              bike:,
              render_search: true,
              search_url: admin_bikes_path(search_bike_id: bike.id)
            ))
          end

          def bike_version
            render(Atoms::Admin::TableCells::Bike::Component.new(bike: BikeVersion.find(1)))
          end
          # @endgroup

          private

          def bike
            ::Bike.find_id(35)
          end
        end
      end
    end
  end
end
