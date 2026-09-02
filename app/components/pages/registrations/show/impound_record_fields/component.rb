# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module ImpoundRecordFields
        # Shared impound-record definition list (created, who impounded, status, last
        # updater, location) — used by the org impound-record card and its panel
        class Component < ApplicationComponent
          def initialize(impound_record:)
            @impound_record = impound_record
          end

          private

          def impounded_by
            @impound_record.user&.display_name
          end

          def last_update_by
            @impound_record.impound_record_updates.reorder(:id).last&.user&.display_name
          end
        end
      end
    end
  end
end
