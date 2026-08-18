# frozen_string_literal: true

module UI
  module Pagination
    class Component < ApplicationComponent
      def initialize(pagy:, page_params:, size: :md, data: {})
        @pagy = pagy
        @params = page_params.is_a?(Hash) ? page_params : page_params.permit!
        @size = size
        @data = data
      end

      def render?
        @pagy.present? && @pagy.count > @pagy.limit
      end

      private

      def size_classes
        if @size == :lg
          "tw:text-xl"
        else
          "tw:h-10 tw:text-base"
        end
      end

      def pagy_series_link(item)
        if item.is_a?(Integer)
          link_to(number_display(item), @params.merge(page: item), class: active_classes, data: @data)
        elsif item.is_a?(String) # it's the current page
          content_tag(:a, number_display(item), role: "link", class: current_link_class, disabled: true, "aria-disabled": "true")
        else
          content_tag(:a, pagy_t("pagy.gap").html_safe, role: "link", class: "px-2", disabled: true, "aria-disabled": "true")
        end
      end

      def pagy_t(key, **opts)
        Pagy::I18n.locale = I18n.locale.to_s
        Pagy::I18n.translate(key, **opts)
      end

      # Multiline classes strings here were confusing tailwind somehow :(
      # relative, because -space-x-px overlaps each border with its neighbor's — only a
      # positioned item can raise its own above them with z-10
      def disabled_classes
        "tw:disabled:cursor-default tw:relative tw:px-3 tw:py-1 tw:leading-tight tw:border tw:border-gray-200 tw:dark:border-gray-700 tw:bg-white tw:dark:bg-gray-800 tw:text-gray-500 tw:dark:text-gray-400 tw:no-underline "
      end

      def active_classes
        disabled_classes + "tw:hover:z-10 tw:hover:border-purple-500 tw:hover:bg-purple-50 tw:hover:text-gray-800 tw:dark:hover:border-purple-500 tw:dark:hover:bg-purple-950 tw:dark:hover:text-white "
      end

      def current_link_class
        # Round the outer edge, if there isn't a prev/next
        extra_classes = if !show_previous
          "tw:rounded-s-md "
        elsif !show_next
          "tw:rounded-e-md "
        else
          ""
        end
        # The current page fills like an active UI::Button secondary
        extra_classes +
          "tw:disabled:cursor-default tw:relative tw:z-10 tw:px-3 tw:py-1 tw:leading-tight tw:border tw:border-purple-500 tw:bg-purple-500 tw:text-white "
      end

      def pagy_series
        @pagy.send(:series)
      end

      def show_previous
        @pagy.previous.present?
      end

      def show_next
        @pagy.next.present?
      end

      def prev_html
        if (p_prev = @pagy.previous)
          link_to(pagy_t("pagy.previous").html_safe, @params.merge(page: p_prev), class: active_classes + " tw:rounded-s-md",
            "aria-label": pagy_t("pagy.aria_label.previous"), data: @data)
        else
          content_tag(:a, pagy_t("pagy.previous").html_safe, role: "link", class: disabled_classes + " tw:rounded-s-md",
            disabled: true, "aria-disabled": "true", "aria-label": pagy_t("pagy.aria_label.previous"))
        end
      end

      def next_html
        if (p_next = @pagy.next)
          link_to(pagy_t("pagy.next").html_safe, @params.merge(page: p_next), class: active_classes + " tw:rounded-e-md",
            "aria-label": pagy_t("pagy.aria_label.next"), data: @data)
        else
          content_tag(:a, pagy_t("pagy.next").html_safe, role: "link", class: disabled_classes + " tw:rounded-e-md",
            disabled: true, "aria-disabled": "true", "aria-label": pagy_t("pagy.aria_label.next"))
        end
      end
    end
  end
end
