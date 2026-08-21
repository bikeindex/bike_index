# frozen_string_literal: true

module Admin
  module Organizations
    module Index
      module SearchForm
        class Component < ApplicationComponent
          SETTINGS = [["With Stolen Message", "with_stolen_message"], ["Opted into Theft Survey", "theft_survey"],
            ["Shown on map", "mapped"], ["NOT shown on map", "not_mapped"], ["Not Approved", "not_approved"]].freeze

          # A hash of arrays renders as combobox option groups. Feature values are ids, so
          # they're stringified to match what comes back in the comma-joined param
          def self.option_groups
            {"Settings" => SETTINGS.map { |display, value| {display:, value:} },
             "Features" => OrganizationFeature.order(name: :desc).pluck(:name, :id)
               .map { |display, value| {display:, value: value.to_s} }}
          end

          def initialize(search_paid:, features_and_settings_ids:, index:)
            @search_paid = search_paid
            @features_and_settings_ids = features_and_settings_ids
            @index = index
          end

          private

          # The combobox keeps its selection in one comma-joined hidden field
          def selected_value = Array(@features_and_settings_ids).join(",")
        end
      end
    end
  end
end
