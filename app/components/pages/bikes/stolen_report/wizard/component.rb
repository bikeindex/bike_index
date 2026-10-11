# frozen_string_literal: true

module Pages
  module Bikes
    module StolenReport
      module Wizard
        # The stolen report, a step at a time - every step is on the page, and stolen-report--wizard
        # shows one. Reporting a theft and editing the report afterward are the same form
        class Component < ApplicationComponent
          STEPS = BikeServices::StolenReport::STEPS
          # The others only need what's required on them to move on
          OPTIONAL_STEPS = %w[photos police contact extra].freeze
          # The register flow's, shown done ahead of these when it hands off here
          REGISTRATION_STEPS = %w[bike_info bike_details].freeze
          PROOF_OF_OWNERSHIP = {"true" => true, "false" => false, "unsure" => nil}.freeze
          # A radio styled as a pill, filled once it's picked
          CHIP_CLASS = "tw:mb-0 tw:inline-flex tw:cursor-pointer tw:items-center tw:rounded-full tw:border-[1.5px] " \
            "tw:border-gray-300 tw:bg-white tw:px-4 tw:py-2 tw:text-sm tw:font-semibold tw:transition-colors " \
            "tw:hover:border-blue-500 tw:has-checked:border-blue-600 tw:has-checked:bg-blue-600 tw:has-checked:text-white " \
            "tw:has-focus-visible:ring-3 tw:has-focus-visible:ring-blue-500/40 tw:dark:border-gray-600 tw:dark:bg-gray-800"
          # A radio styled as a card, for answers too long for a pill
          CARD_CLASS = "tw:mb-0 tw:flex tw:cursor-pointer tw:items-start tw:gap-3 tw:rounded-md tw:border " \
            "tw:border-gray-200 tw:bg-white tw:p-3 tw:text-sm tw:font-normal tw:transition-colors tw:hover:border-blue-500 " \
            "tw:has-checked:border-blue-600 tw:has-checked:bg-blue-50 tw:has-focus-visible:ring-3 tw:has-focus-visible:ring-blue-500/40 " \
            "tw:dark:border-gray-700 tw:dark:bg-gray-800 tw:dark:has-checked:bg-blue-950"
          INVALID_CLASS = "tw:aria-[invalid=true]:border-red-600"

          # missing: the required answers a submission lacked, flagged on render
          # submitted: what that submission held, for the fields that aren't the record's own
          # registered: the bike was just registered for this report, which numbers the
          # registration's two steps ahead of these
          def initialize(bike:, stolen_record:, step: STEPS.first, missing: [], submitted: {}, registered: false)
            @bike = bike
            @stolen_record = stolen_record
            @step = STEPS.include?(step) ? step : STEPS.first
            @missing = missing.map(&:to_s)
            @submitted = submitted.to_h.with_indifferent_access
            @registered = registered
          end

          private

          def editing? = @stolen_record.persisted?

          def cycle_type = @bike.type

          def step_label(step) = render(Pages::Bikes::StolenReport::StepLabel::Component.new(step:, bike_type: @bike.type_titleize))

          def step_offset = @registered ? REGISTRATION_STEPS.count : 0

          def total_steps = STEPS.count + step_offset

          def step_number(step) = STEPS.index(step) + 1 + step_offset

          def step_heading(step, title:, helper:)
            safe_join([
              tag.p(translation(".step_of", number: step_number(step), total: total_steps),
                class: "tw:mb-1 tw:text-xs tw:font-bold tw:tracking-wide tw:text-blue-600 tw:uppercase tw:dark:text-blue-400"),
              tag.h2(title, class: "tw:mb-1 tw:text-2xl tw:font-bold tw:outline-none", tabindex: -1, data: {step_heading: true}),
              tag.p(helper, class: "tw:mb-5 tw:text-sm tw:text-gray-600 tw:dark:text-gray-400")
            ])
          end

          def current?(step) = step == @step

          def panel_class(step) = current?(step) ? "" : "tw:hidden"

          def invalid?(attribute) = @missing.include?(attribute.to_s)

          # Keys the browser draft by bike, so a report started on one isn't restored onto another.
          # Editing a saved report starts from what's saved rather than a draft
          def form_data
            data = {controller: "stolen-report--wizard ui--forms--address-group",
                    "stolen-report--wizard-step-value": @step,
                    "stolen-report--wizard-steps-value": STEPS.to_json,
                    "stolen-report--wizard-optional-value": OPTIONAL_STEPS.to_json,
                    "stolen-report--wizard-offset-value": step_offset,
                    "stolen-report--wizard-visited-value": (editing? ? STEPS : STEPS.first(STEPS.index(@step) + 1)).to_json,
                    "stolen-report--wizard-text-value": summary_text.to_json,
                    "stolen-report--wizard-stock-photos-url-value": stock_photos_bike_stolen_report_path(@bike),
                    "stolen-report--wizard-editing-value": editing?,
                    "stolen-report--wizard-currency-value": @stolen_record.currency_name,
                    "ui--forms--address-group-us-id-value": Country.united_states_id,
                    action: "input->stolen-report--wizard#refresh change->stolen-report--wizard#refresh " \
                      "submit->stolen-report--wizard#submit keydown.enter->stolen-report--wizard#enter " \
                      "popstate@window->stolen-report--wizard#restoreStep turbo:frame-load->stolen-report--wizard#refresh " \
                      "stolen-report--photo:added->stolen-report--wizard#refresh stolen-report--photo:removed->stolen-report--wizard#refresh"}
            return data if editing?

            data.merge(controller: "#{data[:controller]} form-persist",
              form_persist_key_value: "stolen-report-#{@bike.id}",
              "stolen-report--wizard-draft-key-value": "stolen-report-step-#{@bike.id}",
              action: "#{data[:action]} input->form-persist#save change->form-persist#save " \
                "hw-combobox:selection->form-persist#save submit->form-persist#clear " \
                "form-persist:restored@window->stolen-report--wizard#refresh")
          end

          # The words the review's summaries are built from, in the browser
          def summary_text
            {around: translation(".summary_around"), not_added: translation(".not_added_yet"),
             add: translation(".add"), edit: translation(".edit"), done: translation(".done"),
             in_progress: translation(".in_progress"), skipped: translation(".skipped"),
             photos_added: translation(".summary_photos_added", number: "%{number}"), stock_photo: translation(".summary_stock_photo"),
             no_report: translation(".summary_no_report"), visible_to: translation(".summary_visible_to"),
             police: translation(".summary_police"), shops: translation(".summary_shops"), users: translation(".summary_users"),
             value_unknown: translation(".summary_value_unknown"), proof: translation(".summary_proof", answer: "%{answer}"),
             step_of: translation(".step_of", number: "%{number}", total: "%{total}"), progress_saved: progress_saved_text}
          end

          # The draft is kept in the browser as it's entered, which an edit isn't - it saves on submit
          def progress_saved_text = (translation(".progress_saved") unless editing?)

          def future_date? = invalid?(:date) && BikeServices::StolenReport.future_date?(date_value)

          # In the app's zone - stolen-report--wizard rewrites them into the browser's from date_stolen_iso
          def date_value = @submitted.key?(:date) ? @submitted[:date] : @stolen_record.date_stolen&.in_time_zone&.to_date&.iso8601

          def time_value = @submitted.key?(:time) ? @submitted[:time] : @stolen_record.date_stolen&.in_time_zone&.strftime("%H:%M")

          def date_stolen_iso = (@stolen_record.date_stolen&.iso8601 if @submitted.blank?)

          def lock_options = StolenRecord.locking_description_select_options

          def lock_defeat_options = StolenRecord.locking_defeat_description_select_options

          def proof_entries
            {"true" => translation(".yes_answer"), "false" => translation(".no_answer"), "unsure" => translation(".not_sure")}
          end

          def proof_checked?(value)
            return @submitted[:proof_of_ownership] == value if @submitted.key?(:proof_of_ownership)

            !@stolen_record.proof_of_ownership.nil? && PROOF_OF_OWNERSHIP[value] == @stolen_record.proof_of_ownership
          end

          def value_unknown? = Binxtils::InputNormalizer.boolean(@submitted[:value_unknown])

          def phone_visibility_entries
            {phone_for_police: translation(".show_phone_police"),
             phone_for_shops: translation(".show_phone_shops"),
             phone_for_users: translation(".show_phone_users")}
          end

          def checked?(attribute)
            value = @stolen_record.public_send(attribute)
            value.nil? || value
          end

          def photos = @photos ||= @bike.public_images.with_attached_file.limit(2).to_a

          def stock_photos_src
            stock_photos_bike_stolen_report_path(@bike, manufacturer: @bike.mnfg_name, model: @bike.frame_model,
              year: @bike.year, selected_url: @bike.stock_photo_url)
          end

          def serial = (@bike.serial_display unless @bike.no_serial?)

          def submit_text
            editing? ? translation(".save_changes") : translation(".report_as_stolen")
          end
        end
      end
    end
  end
end
