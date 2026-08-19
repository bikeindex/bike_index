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

        # A reader with a passive organization gets the sidebar in the bar's place, which is
        # tailwind alone -- hence no legacy stylesheet. Its rows go current against the page
        # they point at, which no preview is -- that's spec/integration/organized's
        def org_sidebar
          render_with_template(template: "page_block/navbar/wrapper/preview/org_sidebar",
            locals: {component: PageBlock::Navbar::Wrapper::Component.new(current_user: lookbook_user,
              current_user_or_unconfirmed_user: lookbook_user, passive_organization: lookbook_organization)})
        end

        # @display legacy_stylesheet true
        def logo_only
          render(PageBlock::Navbar::Wrapper::Component.new(logo_only: true))
        end
        # @endgroup
      end
    end
  end
end
