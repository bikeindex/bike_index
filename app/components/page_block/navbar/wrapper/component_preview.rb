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

        # lookbook_user is in no organization, so the switcher above the account rows only
        # appears for one who is -- open the account menu to see it. It's capped at
        # PageBlock::Navbar::OrgSidebar::Component::SWITCHER_ORGANIZATIONS, which a database
        # with fewer than that per user won't show; spec/components is where the cap is pinned.
        # Unlike lookbook_user, which is one deliberate account, this searches out whoever has
        # the most memberships -- an arbitrary real person, and their email, in production
        def org_sidebar_organization_switcher
          return production_notice("user and their organizations") if Rails.env.production?
          return missing_notice("user in an organization") if switcher_user.blank?

          render(PageBlock::Navbar::Wrapper::Component.new(current_user: switcher_user,
            current_user_or_unconfirmed_user: switcher_user,
            passive_organization: switcher_user.organization_roles.order(:id).first.organization))
        end

        private

        def switcher_user
          @switcher_user ||= User.joins(:organization_roles)
            .group("users.id").order(Arel.sql("count(*) desc, users.id asc")).first
        end
      end
    end
  end
end
