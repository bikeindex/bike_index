module Admin
  class PosRegistrationMatchesController < Admin::BaseController
    include Binxtils::SortableTable

    def index
      @per_page = permitted_per_page(default: 50)
      @pagy, @collection = pagy(:countish,
        matching_pos_registration_matches.includes(:pos_bike, bike: {current_ownership: :user}).reorder(sortable_order(PosRegistrationMatch)),
        limit: @per_page,
        page: permitted_page)
    end

    helper_method :matching_pos_registration_matches

    protected

    def sortable_columns
      %w[created_at updated_at status]
    end

    def earliest_period_date
      Time.at(1793491200) # 2026-11-01 - POS registration matches introduced
    end

    def matching_pos_registration_matches
      matches = PosRegistrationMatch.all
      @searched_bucket = params[:search_bucket].presence_in(PosRegistrationMatch::BUCKETS)
      matches = matches.public_send(@searched_bucket) if @searched_bucket.present?
      @searched_reason = params[:search_reason] if PosRegistrationMatch::REVIEW_REASONS.key?(params[:search_reason])
      matches = matches.with_review_reason(@searched_reason) if @searched_reason.present?
      @searched_status = params[:search_status] if PosRegistrationMatch.statuses.key?(params[:search_status])
      matches = matches.where(status: @searched_status) if @searched_status.present?
      if params[:user_id].present?
        matches = matches.where(bike_id: Ownership.current.where(user_id: user_subject&.id || params[:user_id]).select(:bike_id))
      end
      matches.where(created_at: @time_range)
    end
  end
end
