# frozen_string_literal: true

module RegistrationShow
  module Wrapper
    class ComponentPreview < ApplicationComponentPreview
      # @param bike_id text "Bike id to render (ignored in production)"
      # @param view_as select { choices: [public, owner, organization] }
      def default(bike_id: nil, view_as: "public")
        bike = preview_bike(bike_id)
        view = preview_view(bike, view_as)
        render(RegistrationShow::Wrapper::Component.new(bike:, current_user: preview_user(view),
          view:, available_views: [view], mapbox_key: ENV["MAPBOX_MAPPING"]))
      end

      private

      # Only production is locked to the public view of a default bike
      def editable?
        !Rails.env.production?
      end

      def preview_bike(bike_id)
        bike = Bike.unscoped.find_by(id: bike_id) if editable? && bike_id.present?
        bike || Bike.unscoped.reorder(:id).last
      end

      def preview_view(bike, view_as)
        return :public unless editable?

        case view_as
        when "owner" then :owner
        when "organization" then bike.organizations.first || :public
        else :public
        end
      end

      def preview_user(view)
        view.is_a?(Organization) ? view.users.first : nil
      end
    end
  end
end
