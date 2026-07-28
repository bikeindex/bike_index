# frozen_string_literal: true

module Admin
  module BikeEdit
    # The admin bike edit form. The creation data below it is Admin::BikeCreationData.
    class Component < ApplicationComponent
      def initialize(bike:, organizations:)
        @bike = bike
        @organizations = organizations
      end

      private

      def manufacturer_label
        safe_join(["Manufacturer",
          tag.em(link_to("mfg bikes", admin_bikes_path(search_manufacturer: @bike.mnfg_name), class: "less-strong"),
            class: "small")], " ")
      end

      def organization_options
        @organization_options ||= @organizations.pluck(:name, :id)
      end

      # includes, because display_name reads through primary_activity_family
      def primary_activity_options
        PrimaryActivity.by_priority.includes(:primary_activity_family).map { [it.display_name, it.id] }
      end

      # Deleted bike_organizations still matter to admins, so this doesn't use @bike's
      def bike_organizations
        @bike_organizations ||= BikeOrganization.unscoped.where(bike_id: @bike.id).includes(:organization).order(:id).to_a
      end
    end
  end
end
