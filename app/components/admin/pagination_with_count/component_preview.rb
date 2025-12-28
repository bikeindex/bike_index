# frozen_string_literal: true

module Admin::PaginationWithCount
  class ComponentPreview < ApplicationComponentPreview
    # @group PaginationWithCount Variants
    def default
      pagy = Pagy::Offset.new(count: 100, page: 1, limit: 25)
      render(Admin::PaginationWithCount::Component.new(
        collection: collection,
        pagy:,
        per_page: 25,
        params: {}
      ))
    end

    def with_viewing_override
      pagy = Pagy::Offset.new(count: 50, page: 1, limit: 25)
      render(Admin::PaginationWithCount::Component.new(
        collection: collection,
        viewing: "Custom Items",
        pagy:,
        per_page: 25,
        params: {}
      ))
    end

    def skip_total
      pagy = Pagy::Offset.new(count: 100, page: 2, limit: 50)
      render(Admin::PaginationWithCount::Component.new(
        collection: collection,
        skip_total: true,
        pagy:,
        per_page: 50,
        params: {}
      ))
    end

    def with_time_range
      pagy = Pagy::Offset.new(count: 75, page: 1, limit: 25)
      time_range = (1.week.ago..Time.current)
      render(Admin::PaginationWithCount::Component.new(
        collection: collection,
        pagy:,
        per_page: 25,
        time_range:,
        period: "week",
        time_range_column: "created_at",
        params: {}
      ))
    end

    private

    def collection
      Bike.all
    end
  end
end
