class Admin::FeedbacksController < Admin::BaseController
  def index
    if params[:type].present?
      type = params[:type] == 'msg' ? nil : params[:type]
      feedbacks = Feedback.where(feedback_type: type).order(created_at: :desc)
      @matching_count = feedbacks.count
    else
      feedbacks = Feedback.order(created_at: :desc)
    end
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @feedbacks = feedbacks.page(page).per(per_page)
  end

  def show
    @feedback = Feedback.find(params[:id])
  end

  def graphs
    render json:
      case params[:start_at]
      when 'past_year'
        Feedback.where('created_at >= ?', Time.now - 1.year)
          .group_by_week(:created_at).count
      when 'all_time'
        Feedback.group_by_month(:created_at).count
      when 'past_week'
        Feedback.where('created_at >= ?', Time.now - 1.week)
          .group_by_hour(:created_at).count
      else
        Feedback.where('created_at >= ?', Time.now - 1.month)
          .group_by_day(:created_at).count
      end
  end
end
