# frozen_string_literal: true

module Registrations
  module Show
    module ViewSwitcher
      # The audience pill (Public view / Your bike / org admin). When the viewer is
      # allowed more than one perspective it becomes a dropdown linking to the
      # others via ?view_as=; otherwise it's a plain badge. The label/color are
      # passed in so the caller keeps nuances like "No longer your bike".
      class Component < ApplicationComponent
        def initialize(bike:, current_view:, available_views:, label:, color:, solid: true, role_label: nil, current_user: nil)
          @bike = bike
          @current_view = current_view
          @available_views = available_views || []
          @label = label
          @color = color
          @solid = solid
          @role_label = role_label
          @current_user = current_user
        end

        private

        # The pill text: the org/audience name, optionally followed by the viewer's
        # role (e.g. "Brakebills · Staff"), the role muted to read as secondary.
        def display_label
          return @label if @role_label.blank?

          safe_join([@label, content_tag(:span, @role_label, class: "tw:font-normal tw:opacity-65")], " · ")
        end

        def switchable?
          @available_views.size > 1 || superuser? || show_legacy_link?
        end

        def superuser?
          @current_user&.superuser?
        end

        # The redesign rollout's escape hatch back to the classic bike show. Uses
        # no_redesign so the viewer isn't redirected straight back to this page.
        def show_legacy_link?
          @current_user&.registration_show_toggleable?
        end

        def legacy_view_link
          link_to(bike_path(@bike, no_redesign: true), class: entry_class) do
            safe_join(["View in ", content_tag(:span, "Legacy Viewer", class: "tw:font-bold")])
          end
        end

        # Superusers get a link to the admin bike page, ahead of the audience views
        def super_admin_link
          link_to(admin_bike_path(@bike.id), class: entry_class) do
            safe_join(["View in ", content_tag(:span, "Super Admin", class: "tw:font-bold")])
          end
        end

        # Organization perspectives ([role, organization] pairs) lead the dropdown,
        # divided from the owner/public views
        def org_views
          @available_views.select { |_kind, organization| organization }
        end

        # Grouped by organization so dividers land between organizations, not
        # between the roles of a single org (a superadmin sees staff + limited)
        def org_view_groups
          org_views.chunk_while { |a, b| a.last == b.last }.to_a
        end

        def other_views
          @available_views.reject { |_kind, organization| organization }
        end

        def entry_link(view)
          return current_entry(view) if view == @current_view

          link_to(registration_path(@bike, view_as: BikeServices::ShowViews.view_param(view)), class: entry_class) do
            safe_join(["View as ", entry_label(view)])
          end
        end

        # The view already showing, so there's nowhere to go - a span rather than a link
        # to the page it's on, and no hover to invite the click
        def current_entry(view)
          content_tag(:span, safe_join(["Viewing as ", entry_label(view)]),
            class: entry_class(active: true), "aria-current": "true")
        end

        def entry_class(active: false)
          base = "tw:block tw:whitespace-nowrap tw:px-4 tw:py-2 tw:text-sm tw:text-gray-700 tw:no-underline tw:dark:text-gray-200"
          return "#{base} tw:bg-gray-100 tw:dark:bg-gray-800" if active

          "#{base} tw:hover:bg-gray-100 tw:dark:hover:bg-gray-800"
        end

        def button_class
          "#{UI::Badge::Component.badge_classes(color: @color, size: :sm, solid: @solid, cursor: "tw:cursor-pointer")} tw:gap-1"
        end

        # The part after "View as" in each dropdown entry. For organization views
        # only the org name is bold, not the role.
        def entry_label(view)
          kind, organization = view
          case kind
          when :owner then content_tag(:span, "owner of bike", class: "tw:font-bold")
          when :public then content_tag(:span, "Public", class: "tw:font-bold")
          else
            safe_join([content_tag(:span, organization.short_name, class: "tw:font-bold"), " ", kind.to_s])
          end
        end
      end
    end
  end
end
