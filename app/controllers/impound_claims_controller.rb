class ImpoundClaimsController < ApplicationController
  before_action :authenticate_user
  before_action :find_impound_claim, only: [:update]

  def create
    @impound_claim = ImpoundClaim.new(permitted_create_params)
    impound_record = @impound_claim.impound_record
    stolen_record = @impound_claim.stolen_record
    bike_type = stolen_record&.bike&.type || impound_record&.bike&.type || "bike"
    impound_type = "#{impound_record&.kind || ImpoundRecord.impounded_kind} #{bike_type}"
    errors = []
    if @impound_claim.impound_record.blank?
      errors << "Unable to find that #{impound_type}"
    elsif !impound_record.active?
      errors << "That #{impound_type} record has been marked '#{impound_record.status_humanized}' and cannot be claimed"
    end
    if stolen_record.blank?
      errors << "Unable to find that bike"
    elsif stolen_record.user != current_user
      errors << "It doesn't look like you own the #{bike_type} you're claiming matches the #{impound_type}"
    end
    if errors.blank?
      @impound_claim.save
      if @impound_claim.valid?
        flash[:success] = "Claim started, please add information"
      else
        errors = @impound_claim.errors.full_messages
      end
    end
    flash[:error] = errors.to_sentence if errors.any?
    redirect_to bike_path(@impound_claim.bike_claimed, contact_owner: 1)
  end

  def update
    if @impound_claim.update(permitted_update_params)
      flash[:success] = "Claim saved"
    else
      flash[:error] = "Unable to save: #{@impound_claim.errors.full_messages.to_sentence}"
    end
    redirect_back(fallback_location: bike_path(@impound_claim.bike_claimed, contact_owner: 1))
  end

  protected

  def permitted_create_params
    params.require(:impound_claim).permit(:impound_record_id, :stolen_record_id)
      .merge(user_id: current_user.id, status: "pending")
  end

  def permitted_update_params
    params.require(:impound_claim).permit(:message, :status)
  end

  def find_impound_claim
    @impound_claim = current_user.impound_claims.find(params[:id])
  end
end
