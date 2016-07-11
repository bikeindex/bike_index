class RegistrationsController < ApplicationController
  # before_filter :find_b_param, only: [:edit, :update]
  # before_filter :ensure_user_allowed_to_edit, only: [:edit, :update]
  layout 'application_revised'

  def new # Attributes assigned in the partial, but can be overridden so it can be used anywhere
  end

  def create
    @b_param = BParam.new(permitted_params)
    @b_param.errors.add :owner_email, 'required' unless @b_param.owner_email.present?
    if @b_param.errors.blank? && @b_param.save
      EmailPartialRegistrationWorker.perform_async(@b_param.id)
    else
      @page_errors = @b_param.errors
      render action: :new
    end
  end

  private

  def permitted_params
    params.require(:b_param).permit(:manufacturer_id,
                                    :owner_email,
                                    :creation_organization_id,
                                    :creator_id,
                                    :stolen,
                                    :primary_frame_color_id,
                                    :secondary_frame_color_id,
                                    :tertiary_frame_color_id)
  end


end