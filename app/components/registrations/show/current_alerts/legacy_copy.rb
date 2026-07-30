# frozen_string_literal: true

module Registrations
  module Show
    module CurrentAlerts
      # These prompts' copy is the legacy overlays', and those keys are already
      # translated into every locale we ship — so read them rather than duplicating
      # English-only copies under each component's own scope
      module LegacyCopy
        OVERLAY_SCOPE = %i[bikes bike_show_overlays].freeze
        CLAIM_SCOPE = %i[shared claim_message].freeze

        private

        def overlay_translation(key, **)
          translation(key, scope: OVERLAY_SCOPE, **)
        end

        def claim_translation(key, **)
          translation(key, scope: CLAIM_SCOPE, **)
        end
      end
    end
  end
end
