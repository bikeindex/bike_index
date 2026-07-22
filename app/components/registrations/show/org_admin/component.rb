# frozen_string_literal: true

module Registrations
  module Show
    module OrgAdmin
      class Component < ApplicationComponent
        OTHER_REGISTRATIONS_LIMIT = 10

        # staff: overrides the computed role so a superadmin can view the org
        # panel as staff or as limited (view_as)
        def initialize(bike:, current_user:, organization:, available_views: [], staff: nil)
          @bike = bike
          @current_user = current_user
          @organization = organization
          @available_views = available_views
          @force_staff = staff
        end

        def render?
          @bike.present? && @organization.present? && @current_user.present? &&
            @current_user.authorized?(@organization) && @bike.visible_by?(@current_user)
        end

        private

        def action_icon(icon, tile: :purple)
          tile_bg, icon_color = case tile
          when :blue then ["tw:bg-[#e7f3fb]", "tw:text-[#016ec2]"]
          when :amber then ["tw:bg-[#fff8e1]", "tw:text-[#caa11a]"]
          else ["tw:bg-[#f0edfa]", "tw:text-[#715eb2]"]
          end
          content_tag(:span, class: "tw:flex tw:size-9 tw:flex-none tw:items-center tw:justify-center tw:rounded-lg #{tile_bg}") do
            helpers.inline_svg_tag("kelsey/registration_show/#{icon}.svg", class: "tw:h-[19px] tw:w-[19px] #{icon_color}")
          end
        end

        def action_label(title, subtitle)
          content_tag(:span, class: "tw:min-w-0") do
            safe_join([
              content_tag(:span, title, class: "tw:block tw:font-bold"),
              content_tag(:span, subtitle, class: "tw:mt-0.5 tw:hidden tw:text-xs tw:opacity-60 tw:lg:block")
            ])
          end
        end

        def staff?
          return @force_staff unless @force_staff.nil?

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

        def status_label
          @bike.status_stolen? ? translation(".stolen") : translation(".not_stolen")
        end

        def status_color
          @bike.status_stolen? ? :error : :success
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

        def activity_name
          @bike.primary_activity&.display_name
        end

        def frame_color_records
          [@bike.primary_frame_color, @bike.secondary_frame_color, @bike.tertiary_frame_color].compact
        end

        def primary_colors_label
          translation(".primary_color", count: frame_color_records.count)
        end

        # A non-breaking space keeps the swatch with the first word; the rest of a
        # long color name wraps, and the " and " between colors still breaks.
        def color_swatches
          frame_color_records.map do |color|
            swatch = render(UI::ColorSwatch::Component.new(display: color.display, name: color.name, size: :sm, align: :baseline))
            safe_join([swatch, "\u00a0", color.name])
          end
        end

        def credibility_scorer
          @credibility_scorer ||= @bike.credibility_scorer
        end

        def credibility_score
          credibility_scorer.score
        end

        # Matches the credibility_scorer_color used on bikes/show
        def credibility_color
          return "#dc3545" if credibility_score < 31
          return "#ffc107" if credibility_score < 70

          "#28a745"
        end

        def credibility_badges
          CredibilityScorer.permitted_badges_hash(credibility_scorer.badges)
        end

        def owner_phone
          @bike.phone if @bike.phoneable_by?(@current_user)
        end

        # The organization's additional registration fields (affiliation, student
        # ID, etc.) for this bike, as [label, value] rows — blank values dropped
        def org_registration_field_rows
          (@organization.additional_registration_fields - ["reg_bike_sticker"]).filter_map do |reg_field|
            bike_attr = OrganizationFeature.reg_field_to_bike_attrs(reg_field)
            value = org_registration_field_value(bike_attr)
            next if value.blank?

            [org_registration_field_label(reg_field, bike_attr), value]
          end
        end

        def org_registration_field_value(bike_attr)
          case bike_attr
          when "organization_affiliation" then @bike.organization_affiliation(@organization)&.humanize
          when "student_id" then @bike.student_id(@organization)
          when "address" then org_registration_address
          else @bike.send(bike_attr)
          end
        end

        # The org's custom label for the field, falling back to the humanized attribute
        def org_registration_field_label(reg_field, bike_attr)
          custom = @organization.registration_field_labels&.dig(reg_field)
          return Binxtils::InputNormalizer.sanitize(custom) if custom.present?

          bike_attr.humanize(keep_id_suffix: true)
        end

        def org_registration_address
          address = @bike.registration_address
          return if address.blank? || address == @organization.default_location&.address_hash_legacy

          [address["address"], address["city"], [address["state"], address["zipcode"]].compact_blank.join(" ")]
            .compact_blank.join(", ").presence
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

        def impound_sub
          staff? ? translation(".impound_sub") : translation(".request_impound_sub")
        end

        def impound_label
          staff? ? translation(".impound") : translation(".request_impound")
        end

        def edit_access_path
          edit_bike_path(@bike, edit_template: @bike.default_edit_template)
        end

        def other_registrations
          @other_registrations ||= (@bike.user.presence&.bikes || Bike.where(owner_email: @bike.owner_email))
            .where.not(id: @bike.id)
        end

        def other_registrations_count
          @other_registrations_count ||= other_registrations.count
        end

        # Most recent registrations only; the rest are reachable via the org search link
        def recent_other_registrations
          @recent_other_registrations ||= other_registrations.reorder(id: :desc).limit(OTHER_REGISTRATIONS_LIMIT)
        end

        def other_registrations_search_path
          organization_registrations_path(organization_id: @organization.to_param, search_email: @bike.owner_email)
        end

        def more_other_registrations?
          other_registrations_count > OTHER_REGISTRATIONS_LIMIT
        end
      end
    end
  end
end
