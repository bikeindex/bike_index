# frozen_string_literal: true

module Admin::PaginationWithCount
  class ComponentPreview < ApplicationComponentPreview
    def default
      collection = Bike.all
      pagy = Pagy.new(count: 100, page: 1, items: 25)
      render(Admin::PaginationWithCount::Component.new(
        collection: collection,
        pagy: pagy,
        per_page: 25,
        params: {}
      ))
    end

    def with_viewing_override
      collection = Bike.all
      pagy = Pagy.new(count: 50, page: 1, items: 25)
      render(Admin::PaginationWithCount::Component.new(
        collection: collection,
        viewing: "Custom Items",
        pagy: pagy,
        per_page: 25,
        params: {}
      ))
    end

    def skip_total
      collection = Bike.all
      pagy = Pagy.new(count: 100, page: 2, items: 50)
      render(Admin::PaginationWithCount::Component.new(
        collection: collection,
        skip_total: true,
        pagy: pagy,
        per_page: 50,
        params: {}
      ))
    end

    def with_time_range
      collection = Bike.all
      pagy = Pagy.new(count: 75, page: 1, items: 25)
      time_range = (1.week.ago..Time.current)
      render(Admin::PaginationWithCount::Component.new(
        collection: collection,
        pagy: pagy,
        per_page: 25,
        time_range: time_range,
        period: "week",
        time_range_column: "created_at",
        params: {}
      ))
    end
  end
end
