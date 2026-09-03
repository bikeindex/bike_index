# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module WrapperConsumer
        class Component < ApplicationComponent
          include BikeHelper

          # owner: overrides the computed ownership, so the wrapper can force view_as
          # marketplace_preview: the public view of a listing that's still a draft
          def initialize(bike:, current_user:, show_for_sale: false, marketplace_preview: false, owner: nil,
            available_views: [], bike_sticker: nil, current_alerts: {})
            @bike = bike
            @current_user = current_user
            @show_for_sale = show_for_sale
            @marketplace_preview = marketplace_preview
            @available_views = available_views
            @bike_sticker = bike_sticker
            @current_alerts = current_alerts
            @owner = owner.nil? ? (@current_user.present? && @bike.owner == @current_user) : owner
          end

          # A listing edit doesn't touch the bike, so its cache version misses one
          def cache_version
            [@bike.current_marketplace_listing&.updated_at, *current_alerts_component.cache_version]
          end

          private

          def current_alerts_component
            @current_alerts_component ||= CurrentAlerts::Wrapper::Component.new(bike: @bike,
              current_user: @current_user, bike_sticker: @bike_sticker, owner: @owner,
              current_alerts: @current_alerts)
          end

          def title
            @bike.name.presence || bike_title_html(@bike)
          end

          def current_view
            return [:marketplace_preview, nil] if @marketplace_preview

            [@owner ? :owner : :public, nil]
          end

          def audience_label
            return translation(".audience_marketplace_preview") if @marketplace_preview
            return translation(".audience_owner", bike_type: @bike.type) if @owner
            return translation(".audience_sent_away", bike_type: @bike.type) if previously_owned?

            translation(".audience_public")
          end

          def audience_color
            return :purple if @marketplace_preview
            return :success if @owner
            return :warning if previously_owned?

            :notice
          end

          # The current user held an ownership that's no longer current (bike sent away)
          def previously_owned?
            return false if @owner || @current_user.blank?

            @bike.ownerships.where(user_id: @current_user.id, current: false).exists?
          end

          # A listed bike gets the marketplace card instead
          def show_marketplace_button?
            !@show_for_sale && @owner && @bike.status_with_owner? &&
              (@bike.current_marketplace_listing&.current? || @current_user&.can_create_listing?)
          end

          def edit_bike_button
            render(UI::ButtonLink::Component.new(href: edit_bike_path(@bike, edit_template: @bike.default_edit_template),
              text: translation(".edit_this_bike", bike_type: @bike.type), color: :purple, size: :lg, html_class: "tw:text-center tw:py-2.5!"))
          end
        end
      end
    end
  end
end
