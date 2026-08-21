# frozen_string_literal: true

module Admin
  module OrganizationsIndex
    module SearchForm
      class Component < ApplicationComponent
        SETTINGS = [["With Stolen Message", "with_stolen_message"], ["Opted into Theft Survey", "theft_survey"],
          ["Shown on map", "mapped"], ["NOT shown on map", "not_mapped"], ["Not Approved", "not_approved"]].freeze

        class << self
          # A hash of arrays renders as combobox option groups. Feature values are ids, so
          # they're stringified to match what comes back in the comma-joined param
          def option_groups
            {"Settings" => SETTINGS.map { |display, value| {display:, value:} },
             "Features" => OrganizationFeature.order(name: :desc).pluck(:name, :id)
               .map { |display, value| {display:, value: value.to_s} }}
          end

          def display_for(value)
            option_groups.values.flatten.find { |option| option[:value] == value }&.fetch(:display)
          end
        end

        def initialize(search_paid:, features_and_settings_ids:)
          @search_paid = search_paid
          @features_and_settings_ids = features_and_settings_ids
        end

        private

        def option_groups = self.class.option_groups

        # The combobox keeps its selection in one comma-joined hidden field
        def selected_value = Array(@features_and_settings_ids).join(",")
      end
    end
  end
end
