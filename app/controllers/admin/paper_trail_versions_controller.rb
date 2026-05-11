# frozen_string_literal: true

module Admin
  class PaperTrailVersionsController < Admin::BaseController
    include Binxtils::SortableTable

    def index
      @per_page = permitted_per_page(default: 50)
      @pagy, @collection = pagy(:countish,
        matching_versions.reorder(sortable_opts),
        limit: @per_page,
        page: permitted_page)
    end

    helper_method :matching_versions

    private

    def sortable_columns
      %w[created_at item_type event].freeze
    end

    def sortable_opts
      "versions.#{sort_column} #{sort_direction}"
    end

    def earliest_period_date
      Time.at(1773878400)
    end

    def matching_versions
      versions = PaperTrail::Version.all

      if params[:search_item_id].present?
        versions = versions.where(item_id: params[:search_item_id])
      end

      if params[:search_item_type].present?
        versions = versions.where(item_type: params[:search_item_type])
      end

      if params[:search_event].present?
        versions = versions.where(event: params[:search_event])
      end

      if params[:user_id].present?
        versions = versions.where(whodunnit: (user_subject&.id || params[:user_id]).to_s)
      end

      @time_range_column = "created_at"
      versions.where(created_at: @time_range)
    end
  end
end
