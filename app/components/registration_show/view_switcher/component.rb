# frozen_string_literal: true

module RegistrationShow
  module ViewSwitcher
    # The audience pill (Public view / Your bike / org admin). When the viewer is
    # allowed more than one perspective it becomes a dropdown linking to the
    # others via ?view_as=; otherwise it's a plain badge. The label/color are
    # passed in so the caller keeps nuances like "No longer your bike".
    class Component < ApplicationComponent
      def initialize(bike:, current_view:, available_views:, label:, color:, solid: true)
        @bike = bike
        @current_view = current_view
        @available_views = available_views || []
        @label = label
        @color = color
        @solid = solid
      end

      private

      def switchable?
        @available_views.size > 1
      end

      def button_class
        "#{UI::Badge::Component.badge_classes(color: @color, size: :sm, solid: @solid, cursor: "tw:cursor-pointer")} tw:gap-1"
      end

      # The part after the italic "View as" in each dropdown entry. Organization
      # views are an [organization, role] pair.
      def entry_label(view)
        case view
        when :owner then "owner of bike"
        when :public then "Public"
        else
          organization, role = view
          "#{organization.short_name} #{role}"
        end
      end

      def view_param(view)
        return view.to_s unless view.is_a?(Array)

        organization, role = view
        "#{organization.to_param}:#{role}"
      end
    end
  end
end
