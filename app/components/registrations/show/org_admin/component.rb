# frozen_string_literal: true

module Registrations
  module Show
    module OrgAdmin
      class Component < ApplicationComponent
        include BikeHelper

        OTHER_REGISTRATIONS_LIMIT = 10
        # Parking-notification statuses that are still ongoing (vs replaced/retrieved/resolved)
        ACTIVE_PARKING_STATUSES = %w[current impounded].freeze
        # Registration fields shown with the owner (their tie to the org) rather than in registration info
        OWNER_ACCESS_REG_FIELDS = %w[reg_organization_affiliation reg_student_id].freeze

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

        # A definition-list row that always renders, showing a muted "-" when blank
        def info_row(label, value = nil, &block)
          render(UI::DefinitionList::Row::Component.new(label:, value:, render_with_no_value: true, no_value_text: "-"), &block)
        end

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

        def unregistered?
          @bike.unregistered_parking_notification?
        end

        # Owner contact + law-enforcement data is only shown to full staff on a bike
        # registered with their organization
        def show_contact?
          staff? && organization_registered?
        end

        # The owner can be messaged (via a stolen/unstolen notification) when the
        # bike is stolen, or when the org can send unstolen notifications
        def contactable?
          @bike.current_stolen_record.present? ||
            (@bike.status_with_owner? && @organization.enabled?("unstolen_notifications"))
        end

        def message_notification
          @message_notification ||= StolenNotification.new(bike: @bike)
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
          bike_title_html(@bike)
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

        def current_ownership
          @current_ownership ||= @bike.current_ownership
        end

        def bike_stickers
          @bike_stickers ||= @bike.bike_stickers.reorder(claimed_at: :desc)
        end

        # Org-owned stickers link to their edit page; others show the code as text
        def sticker_link(bike_sticker)
          return bike_sticker.pretty_code unless bike_sticker.organization_id == @organization.id

          link_to(bike_sticker.pretty_code, edit_organization_sticker_path(id: bike_sticker.code, organization_id: @organization.to_param), class: "twlink")
        end

        def model_audit
          return @model_audit if defined?(@model_audit)

          @model_audit = @bike.model_audit_id.present? ? @bike.model_audit : nil
        end

        # The org's certification record for this bike's model, if any
        def organization_model_audit
          return @organization_model_audit if defined?(@organization_model_audit)

          @organization_model_audit = model_audit &&
            OrganizationModelAudit.find_by(organization_id: @organization.id, model_audit_id: @bike.model_audit_id)
        end

        # The organization's additional registration fields (address, etc.) for
        # this bike, as [label, value] rows — blank values dropped. Sticker, phone,
        # affiliation and student ID are shown elsewhere
        def org_registration_field_rows
          (@organization.additional_registration_fields - %w[reg_bike_sticker reg_phone] - OWNER_ACCESS_REG_FIELDS).filter_map do |reg_field|
            bike_attr = OrganizationFeature.reg_field_to_bike_attrs(reg_field)
            value = org_registration_field_value(bike_attr)
            next if value.blank?

            [org_registration_field_label(reg_field, bike_attr), value]
          end
        end

        # Affiliation & student ID [label, value] rows for owner & access; blank
        # values render a muted "-" rather than dropping
        def owner_reg_field_rows
          (@organization.additional_registration_fields & OWNER_ACCESS_REG_FIELDS).map do |reg_field|
            bike_attr = OrganizationFeature.reg_field_to_bike_attrs(reg_field)
            [org_registration_field_label(reg_field, bike_attr), org_registration_field_value(bike_attr)]
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

          [address["street"], address["city"], [address["state"], address["zipcode"]].compact_blank.join(" ")]
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

        def active_notifications_count
          @active_notifications_count ||= parking_notifications.where(status: ACTIVE_PARKING_STATUSES).count
        end

        def resolved_notifications_count
          @resolved_notifications_count ||= parking_notifications.where.not(status: ACTIVE_PARKING_STATUSES).count
        end

        # Boxed count + label; links to the search only when the count is non-zero
        def parking_stat(count, path, label)
          inner = safe_join([
            content_tag(:span, count, class: "tw:block tw:text-2xl tw:font-bold"),
            content_tag(:span, label, class: "tw:block tw:text-xs")
          ])
          content_tag(:div, class: "tw:rounded-lg tw:border tw:border-gray-200 tw:p-3 tw:text-center tw:dark:border-gray-700") do
            count.positive? ? link_to(inner, path, class: "twlink tw:block") : inner
          end
        end

        def new_parking_notification
          return @new_parking_notification if defined?(@new_parking_notification)

          notification = ParkingNotification.new(bike_id: @bike.id, organization: @organization, use_entered_address: false)
          notification.is_repeat = notification.likely_repeat?
          notification.set_location_from_organization
          notification.kind ||= notification.potential_initial_record&.kind || ParkingNotification.kinds.first
          @new_parking_notification = notification
        end

        def create_parking_notifications_path
          organization_parking_notifications_path(organization_id: @organization.to_param)
        end

        # The seeded US id (Country.united_states_id is a stale constant in dev)
        def us_country_id
          @us_country_id ||= Country.united_states.id
        end

        def notifications_path
          organization_parking_notifications_path(organization_id: @organization.to_param, search_bike_id: @bike.id, search_status: "all")
        end

        def resolved_notifications_path
          organization_parking_notifications_path(organization_id: @organization.to_param, search_bike_id: @bike.id, search_status: "resolved")
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
