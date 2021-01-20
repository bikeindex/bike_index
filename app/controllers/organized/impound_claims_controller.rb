module Organized
  class ImpoundClaimsController < Organized::BaseController
    include SortableTable
    before_action :set_period, only: [:index]
    before_action :find_impound_claim, except: [:index]

    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25

      @impound_claims = available_impound_claims.reorder("impound_claims.#{sort_column} #{sort_direction}")
        .page(@page).per(@per_page)
        .includes(:user, :stolen_record, :impound_record)
    end

    def show
    end

    def update
      # TODO: make it work
    end

    helper_method :available_impound_claims, :available_statuses

    private

    def impound_claims
      # We never want to display pending claims to the organization
      current_organization.impound_claims.where.not(status: "pending")
    end

    def sortable_columns
      %w[created_at updated_at impound_record_id user_id resolved_at]
    end

    def available_statuses
      %w[active resolved all] + ImpoundClaim.statuses - %w[pending] # No pending display
    end

    def available_impound_claims
      if params[:search_status] == "all"
        @search_status = "all"
        a_impound_claims = impound_claims
      else
        @search_status = available_statuses.include?(params[:search_status]) ? params[:search_status] : available_statuses.first
        if ImpoundClaim.statuses.include?(@search_status)
          a_impound_claims = impound_claims.where(status: @search_status)
        else
          a_impound_claims = impound_claims.send(@search_status)
        end
      end

      if params[:search_impound_record_id].present?
        @impound_record = current_organization.impound_records.find_by_id(params[:search_impound_record_id])
        a_impound_claims = a_impound_claims.where(impound_record_id: @impound_record&.id)
      end

      a_impound_claims.where(created_at: @time_range)
    end

    def find_impound_claim
      @impound_claim = impound_claims.find(params[:id])
      @impound_record = @impound_claim.impound_record
      @parking_notification = @impound_record.parking_notification
    end

    def permitted_parameters
      # params.require(:impound_claim)
    end
  end
end
