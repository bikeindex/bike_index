# frozen_string_literal: true

module Admin
  module Bikes
    module CreationData
      # The ownerships and BParams below the admin bike edit form. Collapsed behind a
      # trigger unless the viewer has dev info on, in which case it starts open.
      class Component < ApplicationComponent
        # Ownership columns that have a row of their own above the JSON dump
        SKIPPED_ATTRIBUTES = %w[creator_id bike_id organization_id created_at updated_at token id].freeze

        def initialize(bike:, display_dev_info: false)
          @bike = bike
          @display_dev_info = display_dev_info
        end

        private

        def ownerships
          @ownerships ||= @bike.ownerships.reorder(created_at: :desc)
            .includes(:creator, :organization).to_a
        end

        def b_params
          @b_params ||= @bike.b_params.to_a
        end

        def ownership_kind(ownership)
          if @bike.current_ownership_id == ownership.id
            tag.span("Current", class: UI::Alerts::Base::Component::TEXT_CLASSES[:success])
          elsif ownership.current?
            tag.small("Current but not set on Bike", class: "twless-strong")
          else
            tag.span("transferred", class: UI::Alerts::Base::Component::TEXT_CLASSES[:notice])
          end
        end

        # Deleted organizations still matter to admins, so this doesn't read the association
        def organization_link(ownership)
          return if ownership.organization_id.blank?

          name = Organization.unscoped.find_by_id(ownership.organization_id)&.name || ownership.organization_id
          link_to(name, admin_organization_path(ownership.organization_id), class: "twlink")
        end

        def creator_link(ownership)
          return if ownership.creator_id.blank?

          link_to(ownership.creator&.display_name || ownership.creator_id,
            admin_user_path(ownership.creator_id), class: "twlink")
        end

        def ownership_attributes(ownership)
          ownership.attributes.except(*SKIPPED_ATTRIBUTES)
        end
      end
    end
  end
end
