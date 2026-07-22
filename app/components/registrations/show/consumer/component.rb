# frozen_string_literal: true

module Registrations
  module Show
    module Consumer
      class Component < ApplicationComponent
        # owner: overrides the computed ownership so the wrapper can force the
        # public or owner perspective (view_as)
        def initialize(bike:, current_user:, show_for_sale: false, owner: nil, available_views: [])
          @bike = bike
          @current_user = current_user
          @show_for_sale = show_for_sale
          @available_views = available_views
          @owner = owner.nil? ? (@current_user.present? && @bike.owner == @current_user) : owner
        end

        private

        def title
          @bike.name.presence || helpers.bike_title_html(@bike)
        end

        def subtitle
          parts = [@bike.year, manufacturer_name, @bike.frame_model].compact_blank
          [parts.join(" "), @bike.frame_colors.to_sentence].compact_blank.join(" · ")
        end

        def manufacturer_name
          @bike.manufacturer&.other? ? @bike.mnfg_name : @bike.manufacturer&.name
        end

        # Only vehicles that aren't a standard bike surface the type
        def vehicle_type
          @bike.cycle_type_name unless @bike.type == "bike"
        end

        def audience_label
          return translation(".audience_owner", bike_type: @bike.type) if @owner
          return translation(".audience_sent_away", bike_type: @bike.type) if previously_owned?

          translation(".audience_public")
        end

        def audience_color
          return :success if @owner
          return :warning if previously_owned?

          :notice
        end

        # The current user held an ownership that's no longer current (bike sent away)
        def previously_owned?
          return false if @owner || @current_user.blank?

          @bike.ownerships.where(user_id: @current_user.id, current: false).exists?
        end

        def status_label
          @bike.status_stolen? ? translation(".stolen") : translation(".not_stolen")
        end

        def status_color
          @bike.status_stolen? ? :error : :success
        end

        def activity_name
          @bike.primary_activity&.display_name
        end

        def primary_colors_label
          translation(".primary_color", count: frame_color_records.count)
        end

        def frame_color_records
          [@bike.primary_frame_color, @bike.secondary_frame_color, @bike.tertiary_frame_color].compact
        end

        # A non-breaking space keeps the swatch with the first word; the rest of a
        # long color name wraps, and the " and " between colors still breaks.
        def color_swatches
          frame_color_records.map do |color|
            swatch = render(UI::ColorSwatch::Component.new(display: color.display, name: color.name, size: :sm, align: :baseline))
            safe_join([swatch, "\u00a0", color.name])
          end
        end

        def show_marketplace_button?
          @owner && @bike.status_with_owner? &&
            (@bike.current_marketplace_listing&.current? || @current_user&.can_create_listing?)
        end

        # Half-width next to "Sell on Marketplace" when it shows, full-width otherwise
        def edit_bike_button
          render(UI::ButtonLink::Component.new(href: edit_bike_path(@bike, edit_template: @bike.default_edit_template),
            text: translation(".edit_this_bike", bike_type: @bike.type), color: :purple, size: :lg, class: "tw:justify-center tw:text-center tw:py-2.5!"))
        end
      end
    end
  end
end
