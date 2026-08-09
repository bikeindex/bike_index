# frozen_string_literal: true

module Register
  module Step2
    # Step 2 of the registration flow: the bike details form
    class Component < ApplicationComponent
      def initialize(b_param:, steps:, sequence: nil, current_user: nil)
        @b_param = b_param
        @steps = steps
        @sequence = sequence
        @current_user = current_user
      end

      private

      def cycle_type
        @b_param.type
      end

      # An e-vehicle's safety pages come next, so this form doesn't finish the registration
      def submit_text
        return translation(".next") if @sequence&.registration_sequence_pages&.any?

        translation(".complete_registration", cycle_type: @b_param.type_titleize)
      end

      def organization
        @organization ||= @b_param.creation_organization
      end

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
          .select { BikeServices::Displayer.include_reg_field?(it, organization, reg_field_user) }
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

      # Organizations can rename the fields they require
      def reg_label(field, default)
        helpers.registration_field_label(organization, field) || default
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
        @address_statuses ||= if BikeServices::Displayer.include_reg_field?(:address, organization, reg_field_user)
          Bike.statuses - %w[status_stolen status_impounded unregistered_parking_notification]
        else
          []
        end
      end

      def show_address?
        address_statuses.include?(@b_param.status)
      end

      # form_with has no model here, so fields_for needs the record to render from -
      # read through the same whitelist that turns these into the created bike's address
      def address_record
        @address_record ||= AddressRecord.new(BParam.address_record_attributes(@b_param.bike))
      end

      # An organization asking for more than a standard registration owns the section
      def contact_section_text
        return translation(".contact_info") if reg_fields.none? && address_statuses.none?

        translation(".information_for_org", org_name: organization.short_name)
      end

      # bikes/new knows the status before rendering - here it's picked in this
      # form, so register--status-fields rechecks the list whenever it changes
      def show_phone?
        phone_statuses.include?(@b_param.status)
      end
    end
  end
end
