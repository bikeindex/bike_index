module Organized
  class RegistrationSequencesController < Organized::AdminController
    def index
      @draft = current_organization.registration_sequences.draft.first
      @active = RegistrationSequence.active_for(current_organization)
      @previous = current_organization.registration_sequences.archived.order(end_at: :desc)
    end

    # The show page manages the draft's pages (add / reorder / edit), or previews a non-draft
    def show
      @registration_sequence = current_organization.registration_sequences.find(params[:id])
    end

    # Builds the draft (cloned from the template) the org manages
    def create
      draft = RegistrationSequence.draft_for(current_organization)
      redirect_to organization_registration_sequence_path(organization_id: current_organization.to_param, id: draft.id)
    end
  end
end
