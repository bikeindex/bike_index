module Organized
  class RegistrationSequencesController < Organized::AdminController
    def show
      @live = RegistrationSequence.live_for(current_organization)
      @draft = RegistrationSequence.where(organization: current_organization, status: :draft).first
    end

    def edit
      @draft = RegistrationSequence.draft_for(current_organization)
    end

    def update
      @draft = RegistrationSequence.draft_for(current_organization)
      if @draft.update(permitted_parameters)
        flash[:success] = "Upcoming registration sequence updated"
        redirect_to edit_organization_registration_sequence_path(organization_id: current_organization.to_param)
      else
        flash[:error] = "Unable to update: #{@draft.errors.full_messages.to_sentence}"
        render :edit
      end
    end

    def preview
      @registration_sequence = if params[:version] == "live"
        RegistrationSequence.live_for(current_organization)
      else
        RegistrationSequence.where(organization: current_organization, status: :draft).first
      end
    end

    private

    def permitted_parameters
      params.require(:registration_sequence)
        .permit(pages_attributes: %i[id body image listing_order _destroy])
    end
  end
end
