# frozen_string_literal: true

module UI
  module Badge
    class ComponentPreview < ApplicationComponentPreview
      # @!group Colors
      def success
        render(UI::Badge::Component.new(text: "Donor", color: :success))
      end

      def notice_sm
        render(UI::Badge::Component.new(text: "Organization", color: :notice, size: :sm))
      end

      def notice_sm_with_title
        render(UI::Badge::Component.new(text: "N", title: "Notice", color: :notice, size: :sm))
      end

      def purple_md
        render(UI::Badge::Component.new(text: "Superuser", color: :purple, size: :md))
      end

      def warning_lg
        render(UI::Badge::Component.new(text: "Recovery", color: :warning, size: :lg))
      end

      def gray_sm
        render(UI::Badge::Component.new(text: "Default", color: :gray, size: :sm))
      end

      def gray_xs
        render(UI::Badge::Component.new(text: "optional", size: :xs))
      end

      def error_md
        render(UI::Badge::Component.new(text: "Banned", color: :error, size: :md))
      end

      def cyan_lg
        render(UI::Badge::Component.new(text: "Theft Alert", color: :cyan, size: :lg))
      end

      # Renders nested components, requires template
      def empty_md_with_content
        render_with_template(template: "ui/badge/preview/empty_md_with_content")
      end

      # Saturated background + white text (SOLID_COLORS palette)
      def solid
        render(UI::Badge::Component.new(text: "Member", color: :purple, solid: true))
      end

      # Leading status dot inheriting the text color
      def indicator
        render(UI::Badge::Component.new(text: "Active", color: :success, indicator: true))
      end

      # Leading inline SVG (path under app/assets/images, sans .svg)
      def icon
        render(UI::Badge::Component.new(text: "Registered", color: :notice, icon: "link"))
      end
      # @!endgroup
    end
  end
end
