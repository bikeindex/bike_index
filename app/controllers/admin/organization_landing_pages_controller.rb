# frozen_string_literal: true

module Admin
  class OrganizationLandingPagesController < Admin::BaseController
    include Binxtils::SortableTable

    def index
      @per_page = permitted_per_page(default: 50)
      @pagy, @collection = pagy(:countish,
        matching_organization_landing_pages.includes(:organization).reorder(sortable_opts),
        limit: @per_page,
        page: permitted_page)
    end

    helper_method :matching_organization_landing_pages

    private

    def sortable_columns
      %w[created_at updated_at organization_id enabled].freeze
    end

    def sortable_opts
      "organization_landing_pages.#{sort_column} #{sort_direction}"
    end

    def earliest_period_date
      OrganizationLandingPage.minimum(:created_at) || Time.current
    end

    def matching_organization_landing_pages
      organization_landing_pages = OrganizationLandingPage.all

      if current_organization.present?
        organization_landing_pages = organization_landing_pages.where(organization_id: current_organization.id)
      end

      @time_range_column = sort_column if %w[updated_at].include?(sort_column)
      @time_range_column ||= "created_at"
      organization_landing_pages.where(@time_range_column => @time_range)
    end
  end
end
