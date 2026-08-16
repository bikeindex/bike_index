# frozen_string_literal: true

module PageBlock
  module OrgSidebar
    class ComponentPreview < ApplicationComponentPreview
      # @!group Org sidebar

      # The sidebar is fixed to the viewport, so open the preview standalone to see it
      # land where it does on a page
      def default
        render(PageBlock::OrgSidebar::Component.new(organization: lookbook_organization,
          current_user: lookbook_user))
      end

      def on_registrations_index
        render(PageBlock::OrgSidebar::Component.new(organization: lookbook_organization,
          current_user: lookbook_user, controller_namespace: "organized",
          controller_name: "registrations", action_name: "index"))
      end
      # @endgroup
    end
  end
end
