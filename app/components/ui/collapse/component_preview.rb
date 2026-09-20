# frozen_string_literal: true

module UI
  module Collapse
    # The collapse controller has no component; this previews its markup contract
    # (content + chevron targets), and its ?param=1 URL and localStorage persistence. The
    # URL panel is tall enough to reach over what follows it while it opens.
    class ComponentPreview < ApplicationComponentPreview
      # @!group Persistence
      def with_url_param
        {template: "ui/collapse/component_preview/with_url_param"}
      end

      def with_storage_key
        {template: "ui/collapse/component_preview/with_storage_key"}
      end
    end
  end
end
