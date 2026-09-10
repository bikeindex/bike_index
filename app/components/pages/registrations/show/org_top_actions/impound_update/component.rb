# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module OrgTopActions
        module ImpoundUpdate
          # Accordion panel opened from the org-admin "Update impound" action — renders
          # the org impound-record update form
          class Component < ApplicationComponent
            def initialize(bike:, organization:)
              @bike = bike
              @organization = organization
            end

            def render?
              @bike.status_impounded? && impound_record&.organization_id == @organization.id
            end

            private

            def impound_record
              @impound_record ||= @bike.current_impound_record
            end
          end
        end
      end
    end
  end
end
