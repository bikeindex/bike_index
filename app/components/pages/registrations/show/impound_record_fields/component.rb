# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module ImpoundRecordFields
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

          def impounded_from
            @impound_record.impounded_from_address&.formatted_address_string(visible_attribute: :street)
          end

          def noted_updates
            @impound_record.noted_updates.includes(:user)
          end
        end
      end
    end
  end
end
