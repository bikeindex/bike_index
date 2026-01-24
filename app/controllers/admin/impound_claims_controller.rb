class Admin::ImpoundClaimsController < Admin::BaseController
  include SortableTable

  before_action :find_impound_claim, except: [:index]

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @impound_claims = pagy(:countish,
      matching_impound_claims.includes(:user, :organization, :impound_record, :bike_claimed, :bike_submitting)
        .order(sort_column + " " + sort_direction),
      limit: @per_page,
      page: permitted_page)
  end

  def show
  end

  helper_method :matching_impound_claims, :available_statuses

  protected

  def available_statuses
    %w[all current resolved] + (ImpoundClaim.statuses - ["current"]) # current ordered the way we want to display
  end

  def sortable_columns
    %w[created_at organization_id updated_at status user_id impound_record resolved_at]
  end

  def earliest_period_date
    Time.at(1611367147) # 14 days before first impound claim created
  end

  def matching_impound_claims
    impound_claims = ImpoundClaim

    if params[:search_status] == "all"
      @search_status = "all"
    else
      @search_status = available_statuses.include?(params[:search_status]) ? params[:search_status] : available_statuses.first
      impound_claims = if ImpoundClaim.statuses.include?(@search_status)
        impound_claims.where(status: @search_status)
      else
        impound_claims.public_send(@search_status)
      end
    end

    if params[:search_bike_id].present?
      impound_claims = impound_claims.involving_bike_id(params[:search_bike_id])
    end
    impound_claims = impound_claims.where(organization_id: current_organization.id) if current_organization.present?

    impound_claims.where(created_at: @time_range)
  end

  def find_impound_claim
    @impound_claim = ImpoundClaim.find(params[:id])
    @impound_record = @impound_claim.impound_record
    @parking_notification = @impound_record.parking_notification
  end
end
