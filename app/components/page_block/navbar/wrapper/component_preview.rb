# frozen_string_literal: true

module PageBlock
  module Navbar
    module Wrapper
      class ComponentPreview < ApplicationComponentPreview
        # @!group Navbar

        PAGE = {controller_namespace: nil, controller_name: "welcome", action_name: "index"}.freeze

        # @display legacy_stylesheet true
        def default
          render(PageBlock::Navbar::Wrapper::Component.new(**PAGE))
        end

        # @display legacy_stylesheet true
        def signed_in
          render(PageBlock::Navbar::Wrapper::Component.new(**PAGE, current_user: lookbook_user,
            current_user_or_unconfirmed_user: lookbook_user))
        end

        # @display legacy_stylesheet true
        def with_organization
          render(PageBlock::Navbar::Wrapper::Component.new(**PAGE, current_user: lookbook_user,
            current_user_or_unconfirmed_user: lookbook_user, passive_organization: lookbook_organization))
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
