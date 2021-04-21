class ReviewImpoundClaimsController < ApplicationController
  before_action :authenticate_user
  before_action :find_impound_claim

  def show
  end

  def update
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
end
