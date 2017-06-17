class Admin::FeedbacksController < Admin::BaseController
  def index
    if params[:type].present?
      feedbacks = Feedback.where(feedback_type: params[:type]).order(created_at: :desc)
      @matching_count = feedbacks.count
    else
      feedbacks = Feedback.order(created_at: :desc)
    end
    @page = params[:page] || 1
    @per_page = params[:per_page] || 50
    @feedbacks = feedbacks.page(@page).per(@per_page)
  end

  def show
    @feedback = Feedback.find(params[:id])
  end
end
