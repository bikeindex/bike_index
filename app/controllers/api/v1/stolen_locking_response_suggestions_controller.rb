module Api
  module V1
    class StolenLockingResponseSuggestionsController < ApiV1Controller
      before_filter :cors_preflight_check
      after_filter :cors_set_access_control_headers

      def index
        descriptions = {
          locking_descriptions: StolenRecord.locking_description,
          locking_defeat_descriptions: StolenRecord.locking_defeat_description
        }
        respond_with descriptions
      end
    end
  end
end