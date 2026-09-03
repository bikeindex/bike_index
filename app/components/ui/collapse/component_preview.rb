# frozen_string_literal: true

module UI
  module Collapse
    # The collapse controller has no component; this previews its markup contract
    # (content + chevron targets) and the ?param=1 URL persistence.
    class ComponentPreview < ApplicationComponentPreview
      def with_url_param
        {template: "ui/collapse/component_preview/with_url_param"}
      end
    end
  end
end
