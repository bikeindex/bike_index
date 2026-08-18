# frozen_string_literal: true

module PageBlock
  module OrgSidebar
    class ComponentPreview < ApplicationComponentPreview
      # @!group Org sidebar

      # The sidebar is fixed to the viewport, so open the preview standalone to see it
      # land where it does on a page. Its rows go current against the page they point at,
      # which no preview is -- spec/integration/organized is where that's covered
      def default
        render(PageBlock::OrgSidebar::Component.new(organization: lookbook_organization,
          current_user: lookbook_user))
      end
      # @endgroup
    end
  end
end
