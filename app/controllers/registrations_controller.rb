class RegistrationsController < ApplicationController
  skip_before_filter :set_x_frame_options_header, except: [:new]
  before_filter :simple_header
  layout 'reg_embed'

  def new
    @stolen = params[:stolen] # Passed into embed form
    render layout: 'application_revised'
  end

  def embed # Attributes assigned in the partial, but can be overridden so it can be used anywhere
    @organization = current_organization
    @owner_email = current_user && current_user.email
    @selectable_child_organizations = find_selectable_child_organizations
    @stolen = params[:stolen] ? 1 : 0
    creation_organization_id = @selectable_child_organizations.any? ? nil : @organization&.id
    @b_param ||= BParam.new(creation_organization_id: creation_organization_id,
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

  def simple_header
    @simple_header ||= params[:simple_header]
  end

  def find_selectable_child_organizations
    return [] unless @organization.present? && ActiveRecord::Type::Boolean.new.type_cast_from_database(params[:select_child_organization])
    @organization.child_organizations
  end

  def permitted_params
    params.require(:b_param).permit(:manufacturer_id,
                                    :owner_email,
                                    :creation_organization_id,
                                    :stolen,
                                    :primary_frame_color_id,
                                    :secondary_frame_color_id,
                                    :tertiary_frame_color_id)
          .merge(origin: 'embed_partial')
  end
end
