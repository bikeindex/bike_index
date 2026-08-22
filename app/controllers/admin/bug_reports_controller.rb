module Admin
  class BugReportsController < Admin::BaseController
    include Binxtils::SortableTable
    include API::TokenAuthenticatable

    # Keyed by the BugReport scope each filter applies
    MEMBERSHIP_FILTERS = {"member" => "Only members", "paid_organization" => "Only paid org",
                          "paid_organization_staff" => "Only paid org staff"}.freeze
    STATUS_FILTER_ALL = "all"
    STATUS_FILTER_INVESTIGATE = "investigate"

    # Token requests carry no CSRF token, they authenticate with the token alone
    skip_before_action :verify_authenticity_token, if: :token_request?
    before_action :find_bug_report, only: %i[show update]

    def index
      @per_page = permitted_per_page(default: 50)
      bug_reports = matching_bug_reports.includes(user: %i[membership_active email_bans_active])
      # Only the JSON serializes images
      bug_reports = bug_reports.with_attached_images if request.format.json?
      @pagy, @collection = pagy(:countish,
        bug_reports.reorder("bug_reports.#{sort_column} #{sort_direction}"),
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
      respond_to do |format|
        format.html
        format.json { render json: {bug_report: bug_report_json(@bug_report)} }
      end
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
      new_tags = BugReport.normalized_tags(params[:tags])
      if new_tags.any? && params[:bug_reports_selected].present?
        bug_reports = BugReport.where(id: params[:bug_reports_selected].keys)
        bug_reports.each { it.update(tags: it.tags + new_tags) }
        flash[:success] = "Added tags to #{bug_reports.count} bug #{"report".pluralize(bug_reports.count)}"
      else
        flash[:error] = "Select a tag and at least one bug report"
      end
      redirect_back(fallback_location: admin_bug_reports_path)
    end

    # Chips carry the value verbatim - the combobox removes a selection by the text as typed
    def tag_chips
      chips = params[:combobox_values].to_s.split(",").map do
        helpers.hw_combobox_selection_chip(display: it, value: it, for_id: params[:for_id])
      end

      render turbo_stream: helpers.safe_join(chips)
    end

    helper_method :matching_bug_reports, :searchable_tags, :searchable_receivers,
      :membership_filters, :status_filters, :status_only_filters

    def searchable_tags
      @searchable_tags ||= BugReport.all_tags
    end

    def searchable_receivers
      @searchable_receivers ||= BugReport.all_receivers
    end

    def membership_filters
      MEMBERSHIP_FILTERS
    end

    # Ordered value => label. "Status: investigate" and "All" sit above the per-status options
    def status_filters
      {STATUS_FILTER_INVESTIGATE => "Status: investigate", STATUS_FILTER_ALL => "All"}
        .merge(status_only_filters)
    end

    def status_only_filters
      BugReport.statuses.keys.index_with { |status| "Only #{BugReport.status_display(status)}" }
    end

    protected

    def sortable_columns
      %w[created_at received_at updated_at email receiver user_id github_pull_request status].freeze
    end

    def earliest_period_date
      Time.at(1783296000) # 2026-07-06 - bug reports introduced
    end

    def matching_bug_reports
      bug_reports = BugReport.all
      @searched_tag = params[:search_tag]
      bug_reports = bug_reports.with_tag(@searched_tag) if @searched_tag.present?
      @searched_receiver = params[:search_receiver]
      bug_reports = bug_reports.where(receiver: @searched_receiver) if @searched_receiver.present?
      bug_reports = bug_reports.where(user_id: params[:user_id]) if params[:user_id].present?
      bug_reports = bug_reports.where("email ILIKE ?", "%#{EmailNormalizer.normalize(params[:search_email])}%") if params[:search_email].present?
      @searched_membership = params[:search_membership] if MEMBERSHIP_FILTERS.key?(params[:search_membership])
      bug_reports = filter_by_membership(bug_reports)
      bug_reports = filter_by_status(bug_reports)
      bug_reports = bug_reports.text_search(params[:query]) if params[:query].present?
      bug_reports.where(created_at: @time_range)
    end

    # Explicit scopes rather than a dynamic key, so no user input reaches the query
    def filter_by_membership(bug_reports)
      case @searched_membership
      when "member" then bug_reports.member
      when "paid_organization" then bug_reports.paid_organization
      when "paid_organization_staff" then bug_reports.paid_organization_staff
      else bug_reports
      end
    end

    def filter_by_status(bug_reports)
      @searched_status = status_filters.key?(params[:search_status]) ? params[:search_status] : STATUS_FILTER_INVESTIGATE
      case @searched_status
      when STATUS_FILTER_ALL then bug_reports
      when STATUS_FILTER_INVESTIGATE then bug_reports.investigate
      else bug_reports.where(status: @searched_status)
      end
    end

    private

    # Token requests get the API's JSON errors rather than a flash + redirect
    def require_index_admin!
      token_request? ? require_token_superuser! : super
    end

    def find_bug_report
      @bug_report = BugReport.find(params[:id])
    end

    # Dropping an unknown status rather than letting the enum raise on assignment
    def permitted_params
      permitted = params.require(:bug_report).permit(:github_pull_request, :status, :tags, tags: [])

      BugReport.statuses.key?(permitted[:status]) ? permitted : permitted.except(:status)
    end

    def bug_report_json(bug_report)
      bug_report.as_json(only: %w[id user_id email from_name receiver subject body tags status github_pull_request
        is_member is_paid_organization is_paid_organization_staff received_at created_at updated_at])
        .merge("images" => bug_report.images.map { image_json(it) })
    end

    # BlobUrl serves the CDN rather than a signed redirect, so the url doesn't expire
    def image_json(image)
      {filename: image.filename.to_s, byte_size: image.byte_size,
       content_type: image.content_type, url: BlobUrl.for(image.blob)}
    end
  end
end
