# frozen_string_literal: true

module Pagination
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Pagination::Component.new(pagy: pagy_opt, page_params: {}, data: {turbo_action: "advance"}))
    end

    def large
      render(Pagination::Component.new(pagy: pagy_opt, page_params: {}, size: :lg, data: {turbo_action: "advance"}))
    end

    private

    def pagy_opt
      Pagy.new(count: 1_384_155, limit: 10, page: 100, max_pages: 100)
    end
  end
end
