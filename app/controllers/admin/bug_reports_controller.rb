module Admin
  class BugReportsController < Admin::BaseController
    include Binxtils::SortableTable

    def index
      @per_page = permitted_per_page(default: 50)
      @pagy, @bug_reports = pagy(:countish,
        matching_bug_reports.reorder("bug_reports.#{sort_column} #{sort_direction}"),
        limit: @per_page, page: permitted_page)
    end

    def show
      @bug_report = BugReport.find(params[:id])
    end

    private

    def sortable_columns
      %w[received_at created_at from_address]
    end

    def matching_bug_reports
      bug_reports = BugReport.all
      if params[:search_email].present?
        bug_reports = bug_reports.where("from_address ILIKE ?",
          "%#{EmailNormalizer.normalize(params[:search_email])}%")
      end
      bug_reports.where(created_at: @time_range)
    end
  end
end
