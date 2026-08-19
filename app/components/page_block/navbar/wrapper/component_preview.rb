# frozen_string_literal: true

module PageBlock
  module Navbar
    module Wrapper
      class ComponentPreview < ApplicationComponentPreview
        # @!group Navbar

        # @display legacy_stylesheet true
        def default
          render(PageBlock::Navbar::Wrapper::Component.new)
        end

        # @display legacy_stylesheet true
        def signed_in
          render(PageBlock::Navbar::Wrapper::Component.new(current_user: lookbook_user,
            current_user_or_unconfirmed_user: lookbook_user))
        end

        # @display legacy_stylesheet true
        def logo_only
          render(PageBlock::Navbar::Wrapper::Component.new(logo_only: true))
        end
        # @endgroup

        # A reader with a passive organization gets the sidebar in the bar's place, which is
        # tailwind alone -- hence no legacy stylesheet. Outside the group above, which renders
        # its scenarios onto one page: the sidebar is fixed, so it would cover them. Its rows
        # go current against the page they point at, which no preview is -- that's
        # spec/integration/organized's
        def org_sidebar
          render(PageBlock::Navbar::Wrapper::Component.new(current_user: lookbook_user,
            current_user_or_unconfirmed_user: lookbook_user, passive_organization: lookbook_organization))
        end
      end
    end
  end
end
