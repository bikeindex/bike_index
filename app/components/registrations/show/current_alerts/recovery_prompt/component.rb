# frozen_string_literal: true

module Registrations
  module Show
    module CurrentAlerts
      module RecoveryPrompt
        # The "mark it recovered" form, reached from the recovery link in a theft
        # alert email. The controller hands over the stolen record it matched from
        # session[:recovery_link_token], deleting the token so this shows once.
        # A similar form lives in edit_report_stolen / edit_report_recovered
        class Component < ApplicationComponent
          include LegacyCopy

          def initialize(bike:, stolen_record: nil)
            @bike = bike
            @stolen_record = stolen_record
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
