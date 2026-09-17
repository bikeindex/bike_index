# frozen_string_literal: true

module UI
  module Collapse
    # The collapse controller has no component; this previews its markup contract
    # (content + chevron targets), the ?param=1 URL persistence, and a panel tall
    # enough to reach over what follows it while it opens.
    class ComponentPreview < ApplicationComponentPreview
      def with_content_below
        {template: "ui/collapse/component_preview/with_content_below"}
      end

      def with_url_param
        {template: "ui/collapse/component_preview/with_url_param"}
      end
    end
  end
end
