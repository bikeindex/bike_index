module Organized
  class ImpoundClaimsController < Organized::BaseController
    include SortableTable
    before_action :set_period, only: [:index]
    before_action :find_impound_claim, except: [:index]

    def index
      @per_page = params[:per_page] || 25

      @pagy, @impound_claims = pagy(available_impound_claims.reorder("impound_claims.#{sort_column} #{sort_direction}")
        .includes(:user, :stolen_record, :impound_record), limit: @per_page)
    end

    def show
    end

    def update
      if !@impound_claim.submitting?
        flash[:error] = if @impound_claim.responded?
          "That claim has already been responded to"
        else
          "That claim hasn't been submitted yet (it's #{@impound_claim.status_humanized})"
        end
      else
        update_status = "claim_approved" if params[:submit].match?(/approve/i)
        update_status = "claim_denied" if params[:submit].match?(/den/i)
        if %w[claim_approved claim_denied].include?(update_status)
          # add the response message - but don't deliver a message yet
          @impound_claim.update(permitted_update_params.merge(skip_update: true))
          @impound_claim.skip_update = false
          impound_record_update = @impound_record.impound_record_updates.build(user: current_user,
            kind: update_status,
            impound_claim: @impound_claim)
          if impound_record_update.save
            flash[:success] = impound_record_update.kind_humanized
          else
            flash[:error] = "Unable to record: #{impound_record_update.errors.full_messages.to_sentence}"
          end
        else
          flash[:error] = "Unknown update action"
        end
      end
      redirect_back(fallback_location: organization_impound_claim_path(@impound_claim.id, organization_id: current_organization.id))
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
        a_impound_claims = if ImpoundClaim.statuses.include?(@search_status)
          impound_claims.where(status: @search_status)
        else
          impound_claims.public_send(@search_status)
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

    def permitted_update_params
      params.require(:impound_claim).permit(:response_message)
    end
  end
end
