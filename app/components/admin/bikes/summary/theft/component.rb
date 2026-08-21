# frozen_string_literal: true

module Admin
  module Bikes
    module Summary
      module Theft
        # The stolen record's details, below Admin::Bikes::Summary::Details
        class Component < ApplicationComponent
          def initialize(stolen_record:, bike:, display_dev_info: false)
            @stolen_record = stolen_record
            @bike = bike
            @display_dev_info = display_dev_info
          end

          def render? = @stolen_record.present?

          private

          def callable_by
            return tag.strong("Everyone") if @stolen_record.phone_for_everyone

            [("Users" if @stolen_record.phone_for_users), ("Shops" if @stolen_record.phone_for_shops),
              ("Police" if @stolen_record.phone_for_police)].compact.join(", ")
          end

          def recovery_link
            edit_bike_recovery_url(bike_id: @bike.id, token: @stolen_record.find_or_create_recovery_link_token).to_s
          end
        end
      end
    end
  end
end
