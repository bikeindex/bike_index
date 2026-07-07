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
        UI::Badge::Component.badge_classes(color: @color, size: :sm, solid: @solid, cursor: "tw:cursor-pointer")
      end

      def view_label(view)
        case view
        when :public then t("components.registration_show.consumer.audience_public")
        when :owner then t("components.registration_show.consumer.audience_owner")
        else view.short_name
        end
      end

      def view_param(view)
        view.is_a?(Organization) ? view.to_param : view.to_s
      end
    end
  end
end
