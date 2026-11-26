# frozen_string_literal: true

module Pages
  module Org
    module ImpoundSettings
      # The organization's impound configuration form. The ID prefix field previews the next
      # record's ID as it's edited, and the previous prefixes fill it in (org--impound-settings).
      class Component < ApplicationComponent
        def initialize(organization:, impound_configuration:)
          @organization = organization
          @impound_configuration = impound_configuration
        end

        private

        def next_ids = @next_ids ||= @impound_configuration.next_display_id_integers

        def next_id
          prefix = @impound_configuration.display_id_prefix.to_s
          "#{prefix}#{next_ids[prefix]}"
        end
      end
    end
  end
end
