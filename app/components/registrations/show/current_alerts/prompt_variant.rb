# frozen_string_literal: true

module Registrations
  module Show
    module CurrentAlerts
      # A token prompt renders as the dialog and as the alert at once, so anything that
      # differs between the two is asked here rather than re-derived per prompt
      module PromptVariant
        private

        def alert? = @variant == :alert

        # The alert's copy of a form needs its own field ids, rather than a second
        # #token in the document
        def form_namespace = alert? ? "alert" : nil
      end
    end
  end
end
