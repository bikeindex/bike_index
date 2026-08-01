# frozen_string_literal: true

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

          private

          def recovered_at
            Binxtils::TimeParser.round(@stolen_record.recovered_at || Time.current)
          end
        end
      end
    end
  end
end
