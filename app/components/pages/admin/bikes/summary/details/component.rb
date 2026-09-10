# frozen_string_literal: true

module Pages
  module Admin
    module Bikes
      module Summary
        module Details
          # The registration's thumbnail and the two lists beside it, on every admin screen
          # scoped to one bike.
          class Component < ApplicationComponent
            def initialize(bike:, user: nil, stolen_record: nil, display_dev_info: false)
              @bike = bike
              @user = user
              @stolen_record = stolen_record
              @display_dev_info = display_dev_info
            end

            private

            def status_humanized = @bike.status&.gsub("status_", "")

            def paint_link
              return if @bike.paint_id.blank?

              link_to(@bike.paint_description, edit_admin_paint_url(@bike.paint), class: "twlink tw:text-sm")
            end

            def creator_cell
              return self_registered if @bike.creator == @bike.user
              return tag.small("Creator missing", class: error_classes) if @bike.creator.blank?

              render(Pages::Admin::Users::Cell::Component.new(user: @bike.creator,
                search_url: admin_bikes_path(user_id: @bike.creator_id), render_search: true))
            end

            def self_registered = tag.small("self reg", class: "twless-strong")

            def doorkeeper_app = current_ownership&.doorkeeper_app

            def current_ownership = @current_ownership ||= @bike.current_ownership

            def bulk_import = current_ownership&.bulk_import

            def updator_cell
              return unless @bike.updator_id.present?
              return tag.span("User ##{@bike.updator_id} missing", class: error_classes) if @bike.updator.blank?

              link_to(@bike.updator.display_name, admin_user_path(@bike.updator), class: "twlink")
            end

            def owner_search_url
              @bike.user.present? ? admin_bikes_path(user_id: @bike.user.id) : admin_bikes_path(search_email: @bike.owner_email)
            end

            def address_hash = @address_hash ||= @bike.address_hash

            def registration_address
              @registration_address ||= @bike.registration_address
            end

            # Rendered JSON-ish rather than as a ruby hash, to make it a little easier to read
            def address_display(address)
              "{#{address.map { |key, value| "#{key}: #{"\"#{value}\"" if value.present?}" }.join(", ")}}"
            end

            def separate_registration_address?
              registration_address.present? && registration_address != address_hash
            end

            # Phone rides the stolen record when there is one, which renders it itself
            def render_phone? = @stolen_record.blank? && @bike.phone.present?

            def error_classes = UI::Alerts::Base::Component::TEXT_CLASSES[:error]
          end
        end
      end
    end
  end
end
