# frozen_string_literal: true

module Register
  module Step2
    # Step 2 of the registration flow: the bike details form
    class Component < ApplicationComponent
      def initialize(b_param:, steps:, current_user: nil)
        @b_param = b_param
        @steps = steps
        @current_user = current_user
      end

      private

      def cycle_type
        @b_param.type
      end

      # A theft report and the organization's safety pages both come after this form, so it
      # doesn't always finish the registration. Which statuses have one is rechecked
      # client-side, since the status is picked in this form rather than known when it
      # renders - so the label reads off the same answer both times
      def submit_texts
        @submit_texts ||= Bike.statuses.index_with do |status|
          next translation(".next") if @steps.include?("review") || BikeServices::Register.report_step?(status)

          translation(".complete_registration", cycle_type: @b_param.type_titleize)
        end
      end

      def submit_text = submit_texts[@b_param.status]

      def organization
        @organization ||= @b_param.creation_organization
      end

      # Still offered once unchecked, unchecking being what takes `organization` away
      def auto_organization
        @auto_organization ||= @b_param.auto_organization
      end

      # What the form asks for is the organization's whether or not the box is checked -
      # unchecking collapses its fields rather than dropping them, so checking it again
      # has something to bring back
      def reg_organization
        @reg_organization ||= organization || auto_organization
      end

      # Rendered collapsed, for register--organization to restore (and to disable, since
      # collapsing alone would still submit them)
      def organization_dropped? = organization.blank? && auto_organization.present?

      # Step 1's email settles who this is for, so the name is only asked for here
      def user_name_required?
        !@b_param.self_made?(@current_user)
      end

      # What the account already holds only answers the organization's fields when the
      # registration is the registrant's own - registering for someone else asks for theirs
      def reg_field_user
        @current_user if @b_param.self_made?(@current_user)
      end

      # The additional fields the organization asks for, gated exactly as bikes/new
      # gates them. Resolved once - the gates query, and the section heading below
      # re-checks every one of them
      def reg_fields
        @reg_fields ||= %i[phone extra_registration_number organization_affiliation student_id]
          .select { BikeServices::Displayer.include_reg_field?(it, reg_organization, reg_field_user) }
      end

      def show_extra_registration_number?
        reg_fields.include?(:extra_registration_number)
      end

      def show_organization_affiliation?
        reg_fields.include?(:organization_affiliation)
      end

      def show_student_id?
        reg_fields.include?(:student_id)
      end

      def show_reg_phone?
        reg_fields.include?(:phone)
      end

      # Not one of reg_fields, which head the contact section - this renders with the bike
      # details. user_editable, as bikes/new gates it: only an organization that lets ordinary
      # users assign its stickers. A code already set arrived with a scanned sticker
      def show_bike_sticker?
        @b_param.bike_sticker_code.present? ||
          BikeServices::Displayer.include_reg_field?(:bike_sticker, reg_organization, require_user_editable: true)
      end

      # Organizations can rename the fields they require
      def reg_label(field, default)
        helpers.registration_field_label(reg_organization, field) || default
      end

      # Mirrors bikes/new: stolen needs a contact number, impounded needs one
      # unless the finder has a confirmed phone, and an org can require it outright
      def phone_statuses
        @phone_statuses ||= if show_reg_phone?
          Bike.statuses
        else
          ["status_stolen"] + (@current_user&.phone_confirmed? ? [] : ["status_impounded"])
        end
      end

      # The inverse of phone: stolen and impounded hang their address off their own
      # record, so bikes/new only offers these fields for a plain registration
      # (BikeServices::Displayer.display_edit_address_fields?)
      def address_statuses
        @address_statuses ||= if BikeServices::Displayer.include_reg_field?(:address, reg_organization, reg_field_user)
          Bike.statuses - %w[status_stolen status_impounded unregistered_parking_notification]
        else
          []
        end
      end

      def show_address?
        !organization_dropped? && address_statuses.include?(@b_param.status)
      end

      # form_with has no model here, so fields_for needs the record to render from -
      # read through the same whitelist that turns these into the created bike's address
      def address_record
        @address_record ||= AddressRecord.new(BParam.address_record_attributes(@b_param.bike))
      end

      # An organization asking for more than a standard registration owns the section
      def organization_section? = reg_fields.any? || address_statuses.any?

      def contact_section_text
        return translation(".contact_info") unless organization_section?

        translation(".information_for_org", org_name: reg_organization.short_name)
      end

      # The checkbox heads this section, so the heading can't collapse with the organization
      # the way its fields do - both texts ride along for register--organization to swap between
      def contact_section_label
        return contact_section_text unless auto_organization.present? && organization_section?

        texts = {on: contact_section_text, off: translation(".contact_info")}
        tag.span(texts[organization_dropped? ? :off : :on],
          data: {"register--organization-target": "label", texts: texts.to_json})
      end

      # bikes/new knows the status before rendering - here it's picked in this
      # form, so register--status-fields rechecks the list whenever it changes
      def show_phone?
        phone_statuses.include?(@b_param.status)
      end

      # A phone number is how a theft or a find gets contacted, so those two ask for one
      # rather than offering it. Which of them applies is picked in this form, so the copy
      # for each renders and register--status-fields shows whichever the status names
      def phone_required_texts
        @phone_required_texts ||= BikeServices::Register::REPORT_RECORDS.keys.index_with do |status|
          translation((status == "status_stolen") ? ".phone_required_stolen" : ".phone_required_found", cycle_type:)
        end
      end

      def phone_required? = phone_required_texts.key?(@b_param.status)
    end
  end
end
