class ReviewImpoundClaimsController < ApplicationController
  before_action :authenticate_user
  before_action :find_impound_claim

  def show
  end

  def update
    if params[:submit] == "retrieved_by_owner"
      mark_retrieved_by_owner
    elsif !@impound_claim.submitting?
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
        create_impound_record_update(kind: update_status, impound_claim: @impound_claim)
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

  # ProcessImpoundUpdatesJob merges this claim, recovering its stolen record
  def mark_retrieved_by_owner
    if !@impound_record.authorized?(current_user, no_superuser_override: true)
      flash[:error] = "Only the person who found the bike can mark it returned"
    elsif @impound_claim.approved? && @impound_record.active?
      create_impound_record_update(kind: "retrieved_by_owner", impound_claim: @impound_claim)
    else
      flash[:error] = "Only an approved claim can be marked returned"
    end
  end

  def create_impound_record_update(**attributes)
    impound_record_update = @impound_record.impound_record_updates.create(user: current_user, **attributes)
    if impound_record_update.persisted?
      flash[:success] = impound_record_update.kind_humanized
    else
      flash[:error] = "Unable to record: #{impound_record_update.errors.full_messages.to_sentence}"
    end
  end

  def permitted_update_params
    params.require(:impound_claim).permit(:response_message)
  end
end
