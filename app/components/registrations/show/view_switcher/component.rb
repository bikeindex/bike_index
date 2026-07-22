# frozen_string_literal: true

module Registrations
  module Show
    module ViewSwitcher
      # The audience pill (Public view / Your bike / org admin). When the viewer is
      # allowed more than one perspective it becomes a dropdown linking to the
      # others via ?view_as=; otherwise it's a plain badge. The label/color are
      # passed in so the caller keeps nuances like "No longer your bike".
      class Component < ApplicationComponent
        def initialize(bike:, current_view:, available_views:, label:, color:, solid: true, role_label: nil)
          @bike = bike
          @current_view = current_view
          @available_views = available_views || []
          @label = label
          @color = color
          @solid = solid
          @role_label = role_label
        end

        private

        # The pill text: the org/audience name, optionally followed by the viewer's
        # role (e.g. "Brakebills · Full access"), the role muted to read as secondary.
        def display_label
          return @label if @role_label.blank?

          safe_join([@label, content_tag(:span, @role_label, class: "tw:font-normal tw:opacity-65")], " · ")
        end

        def switchable?
          @available_views.size > 1
        end

        # Organization perspectives ([organization, role] pairs) lead the dropdown,
        # divided from the owner/public views
        def org_views
          @available_views.select { |view| view.is_a?(Array) }
        end

        def other_views
          @available_views.reject { |view| view.is_a?(Array) }
        end

        def entry_link(view)
          active = view == @current_view
          link_to(registration_path(@bike, view_as: view_param(view)), "aria-current": (active ? "true" : nil),
            class: "tw:block tw:whitespace-nowrap tw:px-4 tw:py-2 tw:text-sm tw:text-gray-700 tw:no-underline tw:hover:bg-gray-100 tw:dark:text-gray-200 tw:dark:hover:bg-gray-800 #{"tw:bg-gray-100 tw:dark:bg-gray-800" if active}") do
            safe_join([(active ? "Viewing as" : "View as"), " ", entry_label(view)])
          end
        end

        def button_class
          "#{UI::Badge::Component.badge_classes(color: @color, size: :sm, solid: @solid, cursor: "tw:cursor-pointer")} tw:gap-1"
        end

        # The part after "View as" in each dropdown entry. For organization views
        # ([organization, role] pairs) only the org name is bold, not the role.
        def entry_label(view)
          case view
          when :owner then content_tag(:span, "owner of bike", class: "tw:font-bold")
          when :public then content_tag(:span, "Public", class: "tw:font-bold")
          else
            organization, role = view
            safe_join([content_tag(:span, organization.short_name, class: "tw:font-bold"), " ", role.to_s])
          end
        end

        def view_param(view)
          return view.to_s unless view.is_a?(Array)

          organization, role = view
          "#{organization.to_param}.#{role}"
        end
      end
    end
  end
end
