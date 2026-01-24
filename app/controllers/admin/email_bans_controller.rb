class Admin::EmailBansController < Admin::BaseController
  include SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @collection = pagy(:countish, 
      matching_email_bans.includes(:user).reorder("email_bans.#{sort_column} #{sort_direction}"),
      limit: @per_page,
      page: permitted_page
    )
  end

  helper_method :matching_email_bans

  protected

  def sortable_columns
    %w[created_at reason start_at end_at user_id]
  end

  def matching_email_bans
    email_bans = EmailBan

    @time_range_column = sort_column if %w[updated_at status_changed_at].include?(sort_column)
    @time_range_column ||= "created_at"
    email_bans.where(@time_range_column => @time_range)
  end
end
