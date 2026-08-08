# frozen_string_literal: true

module Register
  module StepReport
    # What the registration is reporting - the theft, or the vehicle that was found.
    # The fields become the created bike's stolen record or its impound record
    class Component < ApplicationComponent
      def initialize(b_param:, sequence: nil, current_user: nil)
        @b_param = b_param
        @sequence = sequence
        @current_user = current_user
      end

      private

      def cycle_type
        @b_param.type
      end

      def stolen?
        @b_param.status_stolen?
      end

      def step_number
        BikeServices::Register.step_number("report", sequence: @sequence, b_param: @b_param)
      end

      def total_steps
        BikeServices::Register.total_steps(@sequence, b_param: @b_param)
      end

      # The safety pages can come after the report, so this doesn't always finish the flow
      def submit_text
        return translation(".next") if step_number < total_steps

        translation(".complete_registration", cycle_type: @b_param.type_titleize)
      end

      # Whatever the step saved before, so coming back to it shows the report as entered
      def report_attrs
        @report_attrs ||= (stolen? ? @b_param.stolen_attrs : @b_param.impound_attrs)
          .with_indifferent_access
      end

      # The two records name their date differently, and a datetime_local field wants
      # wall-clock time. Blank when nothing's saved - register--report-date fills in the
      # browser's now, which the server falls back to anyway
      def date_value
        date = report_attrs[stolen? ? :date_stolen : :impounded_at]
        Binxtils::TimeParser.parse(date)&.in_time_zone&.strftime("%Y-%m-%dT%H:%M") if date.present?
      end

      # form_with has no model here, so fields_for renders from this - the stolen record
      # keeps the address on its own columns, the impound record on an AddressRecord
      def address_record
        @address_record ||= AddressRecord.new(saved_address.slice(*AddressRecord.permitted_params.map(&:to_s)))
      end

      def saved_address
        (stolen? ? report_attrs : report_attrs[:address_record_attributes] || {}).to_h
      end

      # Back goes to whatever came before the report - step 2, or the review the
      # acknowledgment pages end at when the report waited on the emailed link
      def previous_path
        register_path(b_param_token: @b_param.id_token,
          step: BikeServices::Register.step_before("report", sequence: @sequence, b_param: @b_param))
      end

      def phone_visibility_entries
        {phone_for_users: translation(".show_phone_users"),
         phone_for_shops: translation(".show_phone_shops"),
         phone_for_police: translation(".show_phone_police")}
      end

      # The stolen record's defaults, for the boxes a report hasn't been submitted for yet
      def checked?(attribute, default: true)
        value = report_attrs[attribute]
        value.nil? ? default : Binxtils::InputNormalizer.boolean(value)
      end
    end
  end
end
