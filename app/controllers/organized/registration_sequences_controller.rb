module Organized
  class RegistrationSequencesController < Organized::AdminController
    before_action :ensure_access_to_registration_sequences!

    def index
      @draft = current_organization.registration_sequences.draft.first
      @active = RegistrationSequence.active_for(current_organization)
    end

    # Manage the draft's pages (add / reorder / edit)
    def edit
      @registration_sequence = current_organization.registration_sequences.draft.find(params[:id])
    end

    # Builds the draft (cloned from the template) the org manages
    def create
      draft = RegistrationSequence.draft_for(current_organization)
      redirect_to edit_organization_registration_sequence_path(organization_id: current_organization.to_param, id: draft.id)
    end

    private

    # Superusers can view regardless; org admins/members need the feature flag
    def ensure_access_to_registration_sequences!
      return unless ensure_current_organization!
      return true if current_organization.enabled?("registration_sequences") || current_user.superuser?

      raise_do_not_have_access!
    end
  end
end
