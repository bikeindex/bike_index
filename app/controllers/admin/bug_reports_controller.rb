module Admin
  class BugReportsController < Admin::BaseController
    include Binxtils::SortableTable

    before_action :find_bug_report, only: %i[show update]

    def index
      @per_page = permitted_per_page(default: 50)
      @pagy, @collection = pagy(:countish,
        matching_bug_reports.includes(:user)
          .reorder("bug_reports.#{sort_column} #{sort_direction}"),
        limit: @per_page,
        page: permitted_page)

      respond_to do |format|
        format.html
        format.json do
          render json: {bug_reports: @collection.map { bug_report_json(it) }}
                     .merge(page: @pagy.page, per_page: @per_page, total_count: @pagy.count)
        end
      end
    end

    def show
    end

    def update
      if @bug_report.update(permitted_params)
        respond_to do |format|
          format.html { redirect_to admin_bug_report_path(@bug_report), flash: {success: "Bug report updated"} }
          format.json { render json: {bug_report: bug_report_json(@bug_report)} }
        end
      else
        errors = @bug_report.errors.full_messages
        respond_to do |format|
          format.html do
            flash.now[:error] = errors.to_sentence
            render :show, status: :unprocessable_entity
          end
          format.json { render json: {errors:}, status: :unprocessable_entity }
        end
      end
    end

    def assign_tags
      new_tags = split_tags(params[:tags])
      if new_tags.none?
        flash[:error] = "No tag selected"
      else
        bug_reports = BugReport.where(id: (params[:bug_reports_selected] || {}).keys)
        bug_reports.each { it.update(tags: it.tags + new_tags) }
        flash[:success] = "Added tags to #{bug_reports.count} bug #{"report".pluralize(bug_reports.count)}"
      end
      redirect_back(fallback_location: admin_bug_reports_path)
    end

    helper_method :matching_bug_reports, :searchable_tags

    def searchable_tags
      @searchable_tags ||= BugReport.all_tags
    end

    protected

    def sortable_columns
      %w[created_at updated_at email user_id github_pull_request].freeze
    end

    def earliest_period_date
      Time.at(1783296000) # 2026-07-06 - bug reports introduced
    end

    def matching_bug_reports
      bug_reports = BugReport.all
      @searched_tag = params[:search_tag] if searchable_tags.include?(params[:search_tag])
      bug_reports = bug_reports.with_tag(@searched_tag) if @searched_tag.present?
      bug_reports = bug_reports.where(user_id: params[:user_id]) if params[:user_id].present?
      bug_reports = bug_reports.text_search(params[:query]) if params[:query].present?
      bug_reports.where(created_at: @time_range)
    end

    private

    def find_bug_report
      @bug_report = BugReport.find(params[:id])
    end

    def permitted_params
      permitted = params.require(:bug_report).permit(:github_pull_request, :tags, tags: [])
      tags = permitted[:tags]
      tags.is_a?(String) ? permitted.merge(tags: split_tags(tags)) : permitted
    end

    def split_tags(string)
      string.to_s.split(",").map(&:strip)
    end

    def bug_report_json(bug_report)
      bug_report.as_json(only: %w[id user_id email subject body tags github_pull_request
        is_member is_paid_organization is_paid_organization_staff created_at updated_at])
    end
  end
end
