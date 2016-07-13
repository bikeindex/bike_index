class RegistrationsController < ApplicationController
  skip_before_filter :set_x_frame_options_header, except: [:new]
  layout 'reg_embed'

  def new
    render layout: 'application_revised'
  end

  def embed # Attributes assigned in the partial, but can be overridden so it can be used anywhere
    @organization = current_organization
    @creator = @organization && @organization.auto_user || current_user
    @owner_email = current_user && current_user.email || @creator && @creator.email
    @stolen = params[:stolen]
    @b_param ||= BParam.new(creation_organization_id: @organization && @organization.id,
                            creator_id: @creator && @creator.id,
                            owner_email: @owner_email,
                            stolen: @stolen)
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
