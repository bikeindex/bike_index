# frozen_string_literal: true

module Admin
  module OrganizationsIndex
    module SearchForm
      class Component < ApplicationComponent
        SETTINGS = [["With Stolen Message", "with_stolen_message"], ["Opted into Theft Survey", "theft_survey"],
          ["Shown on map", "mapped"], ["NOT shown on map", "not_mapped"], ["Not Approved", "not_approved"]].freeze

        def initialize(search_paid:, features_and_settings_ids:)
          @search_paid = search_paid
          @features_and_settings_ids = features_and_settings_ids
        end

        private

        def option_groups
          [["Settings", SETTINGS], ["Features", OrganizationFeature.order(name: :desc).pluck(:name, :id)]]
        end
      end
    end
  end
end
