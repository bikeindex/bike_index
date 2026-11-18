# frozen_string_literal: true

module Atoms
  module Org
    module ImpoundCurrentLocation
      # Where an impounded bike is now: its storage location and that location's address, or
      # "same as impounded from" when the record knows nothing past where it was picked up
      class Component < ApplicationComponent
        def initialize(impound_record:, kind: nil)
          @impound_record = impound_record
          @kind = kind
        end

        def render?
          @impound_record.location.present? || @impound_record.address_record_id.present?
        end

        private

        def same_as_impounded_from?
          @impound_record.address_record_id.present? && @impound_record.address_record_id == @impound_record.impounded_from_address&.id
        end
      end
    end
  end
end
