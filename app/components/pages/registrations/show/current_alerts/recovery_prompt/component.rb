# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module CurrentAlerts
        module RecoveryPrompt
          # The "mark it recovered" form, reached from a theft alert email's recovery link.
          # A similar form lives in edit_report_stolen / edit_report_recovered
          class Component < ApplicationComponent
            include PromptVariant

            MODAL_ID = "recovery-prompt-modal"

            def initialize(bike:, stolen_record: nil, variant: :modal)
              @bike = bike
              @stolen_record = stolen_record
              @variant = variant
            end

            def render?
              @stolen_record.present?
            end

            # The form's bounds come off the clock, and the alert is rendered into the
            # wrapper's fragment cache — so they have to key it
            def cache_version = [recovered_at, max_recovered_at]

            private

            def recovered_at
              Binxtils::TimeParser.round(@stolen_record.recovered_at || Time.current)
            end

            def max_recovered_at = Time.current.end_of_day
          end
        end
      end
    end
  end
end
