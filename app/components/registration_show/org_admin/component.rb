# frozen_string_literal: true

module RegistrationShow
  module OrgAdmin
    class Component < ApplicationComponent
      def initialize(bike:, current_user:, organization:)
        @bike = bike
        @current_user = current_user
        @organization = organization
      end

      def render?
        @bike.present? && @organization.present? && @current_user.present? &&
          @current_user.authorized?(@organization) && @bike.visible_by?(@current_user)
      end

      private

      # A rounded icon tile for the quick-action bar
      def action_icon(icon, tile: :purple)
        tile_bg, icon_color = case tile
        when :blue then ["tw:bg-[#e7f3fb]", "tw:text-[#016ec2]"]
        when :amber then ["tw:bg-[#fff8e1]", "tw:text-[#caa11a]"]
        else ["tw:bg-[#f0edfa]", "tw:text-[#715eb2]"]
        end
        content_tag(:span, class: "tw:flex tw:size-9 tw:flex-none tw:items-center tw:justify-center tw:rounded-lg #{tile_bg}") do
          helpers.inline_svg_tag("icons/registration_show/#{icon}.svg", class: "tw:h-[19px] tw:w-[19px] #{icon_color}")
        end
      end

      def staff?
        @current_user.member_bike_edit_of?(@organization)
      end

      def organization_registered?
        return @organization_registered if defined?(@organization_registered)

        @organization_registered = @bike.organized?(@organization)
      end

      # Owner contact + law-enforcement data is only shown to full staff on a bike
      # registered with their organization
      def show_contact?
        staff? && organization_registered?
      end

      def role_label
        staff? ? translation(".role_staff") : translation(".role_limited")
      end

      def org_chip_label
        organization_registered? ? @organization.short_name : translation(".not_in_org")
      end

      def org_chip_color
        organization_registered? ? :purple : :warning
      end

      def contact_blocked_title
        organization_registered? ? translation(".restricted_title") : translation(".not_registered_title", org_name: @organization.short_name)
      end

      def contact_blocked_message
        organization_registered? ? translation(".restricted_message") : translation(".not_registered_message", org_name: @organization.short_name)
      end

      def title
        helpers.bike_title_html(@bike)
      end

      def subtitle
        parts = [@bike.year, manufacturer_name, @bike.frame_model].compact_blank
        [parts.join(" "), @bike.frame_colors.to_sentence].compact_blank.join(" · ")
      end

      def manufacturer_name
        @bike.manufacturer&.other? ? @bike.mnfg_name : @bike.manufacturer&.name
      end

      def primary_color_hex
        @bike.primary_frame_color&.display
      end

      def credibility_score
        @credibility_score ||= @bike.credibility_scorer.score
      end

      def duplicate_serial_note
        @bike.duplicate_bikes.any? ? translation(".has_duplicate_serials") : translation(".no_duplicate_serials")
      end

      def owner_phone
        @bike.phone if @bike.phoneable_by?(@current_user)
      end

      def show_notes?
        organization_registered? && @organization.enabled?("registration_notes")
      end

      def bike_organization_note
        @bike_organization_note ||= BikeOrganizationNote.find_by(bike_id: @bike.id, organization_id: @organization.id)
      end

      def notes_url
        organization_bike_path(@bike, organization_id: @organization.to_param)
      end

      def show_parking_notifications?
        @organization.enabled?("parking_notifications")
      end

      def parking_notifications
        @parking_notifications ||= @organization.parking_notifications.where(bike_id: @bike.id)
      end

      def current_notifications_count
        @current_notifications_count ||= parking_notifications.current.count
      end

      def resolved_notifications_count
        @resolved_notifications_count ||= parking_notifications.resolved.count
      end

      def notifications_path
        organization_parking_notifications_path(organization_id: @organization.to_param, search_bike_id: @bike.id, search_status: "all")
      end

      def show_impound?
        @organization.enabled?("impound_bikes")
      end

      def impound_path
        organization_impound_records_path(organization_id: @organization.to_param, search_bike_id: @bike.id, search_status: "all")
      end

      def impound_label
        staff? ? translation(".impound") : translation(".request_impound")
      end

      def edit_access_path
        edit_bike_path(@bike, edit_template: @bike.default_edit_template)
      end

      def other_user_bikes
        @other_user_bikes ||= (@bike.user.presence&.bikes || Bike.where(owner_email: @bike.owner_email))
          .reorder(id: :desc).limit(10)
      end
    end
  end
end
