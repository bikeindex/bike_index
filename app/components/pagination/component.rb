# frozen_string_literal: true

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
      Pagy::I18n.translate(I18n.locale, key, **opts)
    end

    # Multiline classes strings here were confusing tailwind somehow :(
    def disabled_classes
      "tw:disabled:cursor-default tw:px-3 tw:py-1 tw:leading-tight tw:border tw:border-gray-300 tw:dark:border-gray-700 tw:bg-white tw:dark:bg-gray-800 tw:text-gray-500 tw:dark:text-gray-400 "
    end

    def active_classes(current = false)
      disabled_classes + "tw:dark:hover:bg-gray-700 tw:hover:bg-gray-100 tw:hover:text-gray-700 tw:dark:hover:text-white "
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
      extra_classes +
        "tw:disabled:cursor-default tw:px-3 tw:py-1 tw:leading-tight tw:border tw:border-gray-300 tw:dark:border-gray-700 tw:bg-gray-200 tw:dark:bg-gray-600 tw:text-gray-800 tw:dark:text-gray-200 "
    end

    def show_previous
      @pagy.prev.present?
    end

    def show_next
      @pagy.next.present?
    end

    def prev_html
      if (p_prev = @pagy.prev)
        link_to(pagy_t("pagy.prev").html_safe, @params.merge(page: p_prev), class: active_classes + " tw:rounded-s-md",
          "aria-label": pagy_t("pagy.aria_label.prev"), data: @data)
      else
        content_tag(:a, pagy_t("pagy.prev").html_safe, role: "link", class: disabled_classes + " tw:rounded-s-md",
          disabled: true, "aria-disabled": "true", "aria-label": pagy_t("pagy.aria_label.prev"))
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
