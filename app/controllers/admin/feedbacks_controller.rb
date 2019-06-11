class Admin::FeedbacksController < Admin::BaseController
  include SortableTable
  layout "new_admin"
  before_action :set_period, only: [:index]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @feedbacks = matching_feedbacks.reorder("feedbacks.#{sort_column} #{sort_direction}")
                                   .page(page).per(per_page)
  end

  def show
    @feedback = Feedback.find(params[:id])
  end

  helper_method :available_feedbacks

  private

  def sortable_columns
    %w[created_at feedback_type]
  end

  def matching_feedbacks
    feedbacks = Feedback
    if params[:search_type].present?
      feedbacks = feedbacks.where(feedback_type: params[:search_type] == "msg" ? nil : params[:search_type])
    end
    if params[:search_user_id].present?
      @user = User.username_friendly_find(params[:search_user_id])
      feedbacks = feedbacks.where(user_id: @user.id) if @user.present?
    end
    if params[:search_bike_id].present?
      feedbacks = feedbacks.bike(params[:search_bike_id])
    end
    feedbacks
  end

  def available_feedbacks
    matching_feedbacks.where(created_at: @time_range)
  end
end
