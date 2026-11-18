# frozen_string_literal: true

module Atoms
  module Org
    module ImpoundCurrentLocation
      # Where an impounded bike is held now
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
          @impound_record.address_record&.impounded_from?
        end
      end
    end
  end
end
