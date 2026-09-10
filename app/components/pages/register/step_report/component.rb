# frozen_string_literal: true

module Pages
  module Register
    module StepReport
      # What the registration is reporting - the theft, or the vehicle that was found.
      # The fields become the created bike's stolen record or its impound record
      class Component < ApplicationComponent
        def initialize(b_param:, steps:, sequence: nil)
          @b_param = b_param
          @steps = steps
          @sequence = sequence
        end

        private

        def cycle_type
          @b_param.type
        end

        # Memoized: every branch on this page asks, and BParam#status re-dups the params
        def stolen?
          return @stolen unless @stolen.nil?

          @stolen = @b_param.status_stolen?
        end

        def heading
          stolen? ? translation(".report_your_stolen", cycle_type:) : translation(".about_the_one_you_found", cycle_type:)
        end

        def subtitle
          stolen? ? translation(".the_more_we_know") : translation(".help_us_reunite")
        end

        def date_label
          stolen? ? translation(".when_was_it_stolen", cycle_type:) : translation(".when_did_you_find_it")
        end

        def street_label
          stolen? ? translation(".where_was_it_stolen") : translation(".address_where_you_found_it")
        end

        # The safety pages can come after the report, or already be signed when the emailed
        # link is what opened it - the step list is the same either way, so what says whether
        # this finishes the registration is whether anything is left to agree to
        def submit_text
          return translation(".next") unless BikeServices::Register.acknowledged?(@b_param, sequence: @sequence)

          translation(".complete_registration", cycle_type: @b_param.type_titleize)
        end

        # Whatever the step saved before, so coming back to it shows the report as entered
        def report_attrs
          @report_attrs ||= (stolen? ? @b_param.stolen_attrs : @b_param.impound_attrs)
            .with_indifferent_access
        end

        # The two records name their date differently. Blank until it's answered - a field
        # that opens on the current time is one nobody corrects, and the theft time is the
        # answer least likely to be now
        def report_date
          @report_date ||= Binxtils::TimeParser
            .parse(report_attrs[stolen? ? :date_stolen : :impounded_at], parse_error: :nil)
        end

        # A datetime_local field holds wall-clock time, and this is the app's zone - the zone
        # a submission that arrives without one is read back in. dateInputUpdateZone rewrites
        # it into the browser's from data-initialtime, and posts that zone alongside
        def date_value = report_date&.in_time_zone&.strftime("%Y-%m-%dT%H:%M")

        # form_with has no model here, so fields_for renders from this - the stolen record
        # keeps the address on its own columns, the impound record on an AddressRecord
        def address_record
          @address_record ||= AddressRecord.new((stolen? ? report_attrs : report_attrs[:address_record_attributes] || {})
            .slice(*AddressRecord.permitted_params))
        end

        # Read off the list rather than hardcoded - where the report sits is the flow's to say
        def previous_path
          register_path(b_param_token: @b_param.id_token,
            step: BikeServices::Register.step_before("report", steps: @steps))
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
end
