module Organized
  class RegistrationSequencesController < Organized::AdminController
    def index
      @draft = current_organization.registration_sequences.draft.first
      @active = RegistrationSequence.active_for(current_organization)
      @previous = current_organization.registration_sequences.archived.order(end_at: :desc)
    end

    def show
      @registration_sequence = current_organization.registration_sequences.find(params[:registration_sequence_id])
    end

    # Builds the draft (cloned from the template) the org edits
    def create
      draft = RegistrationSequence.draft_for(current_organization)
      redirect_to edit_organization_registration_sequence_path(organization_id: current_organization.to_param, registration_sequence_id: draft.id)
    end

    def edit
      @draft = find_draft
    end

    def update
      @draft = find_draft
      if @draft.update(permitted_parameters)
        flash[:success] = "Upcoming registration sequence updated"
        redirect_to edit_organization_registration_sequence_path(organization_id: current_organization.to_param, registration_sequence_id: @draft.id)
      else
        flash[:error] = "Unable to update: #{@draft.errors.full_messages.to_sentence}"
        render :edit
      end
    end

    private

    def find_draft
      current_organization.registration_sequences.draft.find(params[:registration_sequence_id])
    end

    def permitted_parameters
      params.require(:registration_sequence)
        .permit(registration_sequence_pages_attributes: [:id, :image, :listing_order, :_destroy, {bullet_points: []}])
    end
  end
end
