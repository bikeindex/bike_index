# frozen_string_literal: true

module Admin
  module Organizations
    module CustomLayouts
      module Index
        # The custom layouts tab's listing: every template the organization can customize,
        # and where the ones that aren't landing pages are edited from.
        class Component < ApplicationComponent
          def initialize(organization:, display_dev_info: false)
            @organization = organization
            @display_dev_info = display_dev_info
          end

          private

          def version_history_url = ENV["CUSTOM_CODE_SOURCE"]
        end
      end
    end
  end
end
