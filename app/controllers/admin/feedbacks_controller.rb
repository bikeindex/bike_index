class Admin::FeedbacksController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]

  def index
    page = params[:page] || 1
    @per_page = params[:per_page] || 50
    @feedbacks = available_feedbacks.reorder("feedbacks.#{sort_column} #{sort_direction}")
      .page(page).per(@per_page)
    @render_kind_counts = InputNormalizer.boolean(params[:search_kind_counts])
  end

  def show
    @feedback = Feedback.find(params[:id])
    if @feedback&.feedback_hash&.include?("bike_id")
      @bike = Bike.unscoped.find_by_id(@feedback.feedback_hash["bike_id"])
    end
  end

  helper_method :available_feedbacks, :permitted_kinds

  private

  def sortable_columns
    %w[created_at feedback_type]
  end

  def permitted_kinds
    %w[all stolen_tip] + Feedback.kinds
  end

  def matching_feedbacks
    feedbacks = Feedback
    if params[:search_kind].present? && permitted_kinds.include?(params[:search_kind])
      @search_kind = params[:search_kind]
      feedbacks = feedbacks.public_send(@search_kind) unless @search_kind == "all"
    else
      @search_kind = "all"
    end
    if params[:user_id].present?
      @user = User.username_friendly_find(params[:user_id])
      feedbacks = feedbacks.where(user_id: @user.id) if @user.present?
    end
    if params[:search_email].present?
      feedbacks = feedbacks.where("email ILIKE ?", "%#{EmailNormalizer.normalize(params[:search_email])}%")
    end
    if params[:search_bike_id].present?
      feedbacks = feedbacks.bike(params[:search_bike_id])
    end
    feedbacks
  end

  def available_feedbacks
    matching_feedbacks.where(created_at: @time_range)
  end

  # Override earliest period date, to use 1 week before first feedback created
  def earliest_period_date
    Time.at(1362190586)
  end
end
