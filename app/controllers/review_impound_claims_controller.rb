class ReviewImpoundClaimsController < ApplicationController
  before_action :authenticate_user
  before_action :find_impound_claim

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
    redirect_back(fallback_location: review_impound_claim_path(@impound_claim.id))
  end

  protected

  def find_impound_claim
    impound_claim = ImpoundClaim.find(params[:id])
    organization_id = impound_claim.impound_record.organization_id
    if organization_id.present?
      redirect_to organization_impound_claim_path(params[:id], organization_id: organization_id)
      return
    end
    @impound_record = impound_claim.impound_record
    if @impound_record.authorized?(current_user)
      @impound_claim = impound_claim
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def permitted_update_params
    params.require(:impound_claim).permit(:response_message)
  end
end
