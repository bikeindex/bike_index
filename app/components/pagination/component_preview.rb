# frozen_string_literal: true

module Pagination
  class ComponentPreview < ApplicationComponentPreview
    # @group Pagination Variants
    # @param page "The page of pagination"
    def first_page(page: 1)
      pagy_a = pagy_arg(default_opts.merge(page:))
      render(Pagination::Component.new(pagy: pagy_a, page_params: {}, size: :lg, data: {turbo_action: "advance"}))
    end

    def middle_page(page: 3)
      pagy_a = pagy_arg(default_opts.merge(page:))
      render(Pagination::Component.new(pagy: pagy_a, page_params: {}, size: :lg, data: {turbo_action: "advance"}))
    end

    def last_page(page: 100)
      pagy_a = pagy_arg(default_opts.merge(page:))
      render(Pagination::Component.new(pagy: pagy_a, page_params: {}, size: :lg, data: {turbo_action: "advance"}))
    end

    def middle_page_md_size(page: 10)
      pagy_a = pagy_arg(default_opts.merge(page:))
      render(Pagination::Component.new(pagy: pagy_a, page_params: {}, size: :md, data: {turbo_action: "advance"}))
    end

    private

    def pagy_arg(opts = default_opts)
      Pagy.new(**opts)
    end

    def default_opts
      {count: 1_384_155, limit: 10, page: 3, max_pages: 100}
    end
  end
end
