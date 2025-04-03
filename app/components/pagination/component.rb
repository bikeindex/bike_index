# frozen_string_literal: true

module Pagination
  class Component < ApplicationComponent
    # include Pagy::Frontend

    def initialize(pagy:, params:, data: {})
      @pagy = pagy
      @params = params.is_a?(Hash) ? params : params.permit!
      @data = data
    end

    private

    def pagy_series_link(item)
      if item.is_a?(Integer)
        link_to(item, @params.merge(page: item), class: link_classes, data: @data)
      elsif item.is_a?(String)
        content_tag(:a, item, role: "link", class: link_classes(true), disabled: true, "aria-disabled": "true")
      else
        content_tag(:a, pagy_t('pagy.gap').html_safe, role: "link", class: "", disabled: true, "aria-disabled": "true")
      end
    end

    def pagy_t(key, **opts)
      Pagy::I18n.translate(I18n.locale, key, **opts)
    end

    def link_classes(current = false)
      default_classes = " tw:block tw:rounded-lg tw:px-3 tw:py-1 tw:bg-gray-200 tw:hover:bg-gray-300 "

      if current
        "tw:text-white tw:bg-gray-400 tw:cursor-default"
      else
        "tw:disabled:text-gray-300 tw:disabled:bg-gray-100 tw:disabled:cursor-default"
      end + default_classes
    end

    def prev_html
      if (p_prev = @pagy.prev)
        link_to(pagy_t('pagy.prev').html_safe, @params.merge(page: p_prev), class: link_classes,
          aria_label: pagy_t('pagy.aria_label.prev'), data: @data)
      else
        content_tag(:a, pagy_t('pagy.prev').html_safe, role: "link", class: link_classes,
          disabled: true, "aria-disabled": "true", "aria-label": pagy_t('pagy.aria_label.prev'))
      end
    end

    def next_html
      if (p_next = @pagy.next)
        link_to(pagy_t('pagy.next').html_safe, @params.merge(page: p_next), class: link_classes,
          aria_label: pagy_t('pagy.aria_label.next'), data: @data)
      else
        content_tag(:a, pagy_t('pagy.next').html_safe, role: "link", class: link_classes,
          disabled: true, "aria-disabled": "true", "aria-label": pagy_t('pagy.aria_label.next'))
      end
    end
  end
end
