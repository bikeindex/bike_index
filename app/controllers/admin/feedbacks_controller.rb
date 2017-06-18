class Admin::FeedbacksController < Admin::BaseController
  before_filter :find_feedback_for_params, except: [:show]

  def index
    @matching_count = @feedbacks.count if params[:type].present?
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @feedbacks = @feedbacks.order(created_at: :desc)
                           .page(page).per(per_page)
  end

  def show
    @feedback = Feedback.find(params[:id])
  end

  def graphs
    render json:
      case params[:start_at]
      when 'past_year'
        @feedbacks.where('created_at >= ?', Time.now - 1.year)
          .group_by_week(:created_at).count
      when 'all_time'
        @feedbacks.group_by_month(:created_at).count
      when 'past_week'
        @feedbacks.where('created_at >= ?', Time.now - 1.week)
          .group_by_hour(:created_at).count
      else
        @feedbacks.where('created_at >= ?', Time.now - 1.month)
          .group_by_day(:created_at).count
      end
  end

  private

  def find_feedback_for_params
    if params[:type].present?
      @feedbacks = Feedback.where(feedback_type: (params[:type] == 'msg' ? nil : params[:type]))
    else
      @feedbacks = Feedback
    end
  end
end
