# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module BikeDetails
        # The "Bike details" spec-sheet card. The serial is rendered for the given
        # user, so the public view passes nil to keep a hidden serial hidden.
        class Component < ApplicationComponent
          def initialize(bike:, serial_user: nil)
            @bike = bike
            @serial_user = serial_user
          end

          private

          def manufacturer_name
            @bike.manufacturer&.other? ? @bike.mnfg_name : @bike.manufacturer&.name
          end

          # Its Bike Book model's page, unless the catalog has since dropped the model
          def bikebook_model_path
            return @bikebook_model_path if defined?(@bikebook_model_path)

            model = @bike.vehicle_specification&.bikebook_model
            @bikebook_model_path = (ReadableQuery.path(bikebook_path, vehicle_models: model.catalog_id) if model && !model.deleted?)
          end

          # Only vehicles that aren't a standard bike surface the type
          def vehicle_type
            @bike.cycle_type_name unless @bike.type == "bike"
          end
        end
      end
    end
  end
end
