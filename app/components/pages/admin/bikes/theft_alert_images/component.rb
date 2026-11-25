# frozen_string_literal: true

module Pages
  module Admin
    module Bikes
      module TheftAlertImages
        # The registration's photos and the promoted-alert images generated from them, on the
        # stolen bike and theft alert edit screens.
        class Component < ApplicationComponent
          def initialize(bike:, stolen_record:, return_to: nil)
            @bike = bike
            @stolen_record = stolen_record
            @return_to = return_to
          end

          private

          def public_images = @public_images ||= @bike.public_images.to_a

          def alert_image_versions
            @alert_image_versions ||= BikeServices::Displayer.header_image_urls(@bike)
          end

          def alert_images?
            alert_image_versions.present? &&
              (@stolen_record.images_attached? || @stolen_record.alert_image.present?)
          end

          def regenerate_path(image_id)
            admin_stolen_bike_path(@bike, public_image_id: image_id, update_action: "regenerate_alert_image")
          end

          def delete_path(image_id)
            admin_stolen_bike_path(@bike, public_image_id: image_id, update_action: "delete")
          end
        end
      end
    end
  end
end
