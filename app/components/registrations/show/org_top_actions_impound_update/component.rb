# frozen_string_literal: true

module Registrations
  module Show
    module OrgTopActionsImpoundUpdate
      # Accordion panel opened from the org-admin "Update impound" action — renders
      # the org impound-record update form
      class Component < ApplicationComponent
        def initialize(bike:, organization:)
          @bike = bike
          @organization = organization
        end

        def render?
          @bike.status_impounded? && impound_record.present?
        end

        private

        def impound_record
          @impound_record ||= @bike.current_impound_record
        end
      end
    end
  end
end
