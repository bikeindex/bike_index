# frozen_string_literal: true

module Pages
  module Admin
    module Bikes
      module Edit
        # The admin bike edit form. The creation data below it is Pages::Admin::Bikes::CreationData.
        class Component < ApplicationComponent
          def initialize(bike:, organizations:, display_dev_info: false)
            @bike = bike
            @organizations = organizations
            @display_dev_info = display_dev_info
          end

          private

          def manufacturer_label
            safe_join(["Manufacturer",
              tag.em(link_to("mfg bikes", admin_bikes_path(search_manufacturer: @bike.mnfg_name), class: "twless-strong"),
                class: "tw:text-xs")], " ")
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
            @bike_organizations ||= BikeOrganization.unscoped.where(bike_id: @bike.id)
              .includes(:organization).order(:id).to_a
          end

          def current_stolen_record_fields?(stolen_form)
            stolen_form.object.current
          end
        end
      end
    end
  end
end
