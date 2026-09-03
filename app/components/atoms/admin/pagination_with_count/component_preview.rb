# frozen_string_literal: true

module Atoms
  module Admin
    module PaginationWithCount
      class ComponentPreview < ApplicationComponentPreview
        # @!group PaginationWithCount Variants
        def default
          render(Atoms::Admin::PaginationWithCount::Component.new(
            collection:,
            index: index_state(count: 100, limit: 25)
          ))
        end

        def many_pages
          render(Atoms::Admin::PaginationWithCount::Component.new(
            collection:,
            viewing: "application",
            index: index_state(count: 559, limit: 50)
          ))
        end

        def with_viewing_override
          render(Atoms::Admin::PaginationWithCount::Component.new(
            collection:,
            viewing: "Custom Items",
            index: index_state(count: 50, limit: 25)
          ))
        end

        def skip_total
          render(Atoms::Admin::PaginationWithCount::Component.new(
            collection:,
            skip_total: true,
            index: index_state(count: 100, limit: 50, page: 2)
          ))
        end

        def with_time_range
          render(Atoms::Admin::PaginationWithCount::Component.new(
            collection:,
            index: index_state(count: 75, limit: 25, period: "week",
              time_range: 1.week.ago..Time.current, time_range_column: "created_at")
          ))
        end

        private

        def index_state(count:, limit:, page: 1, **attrs)
          ComponentStructs::IndexState.new(
            pagy: Pagy::Offset.new(count:, page:, limit:), per_page: limit, **attrs
          )
        end

        def collection
          Bike.all
        end
      end
    end
  end
end
