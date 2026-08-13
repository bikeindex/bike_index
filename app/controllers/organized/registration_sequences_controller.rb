module Organized
  class RegistrationSequencesController < Organized::AdminController
    before_action :ensure_access_to_registration_sequences!
    before_action :ensure_access_to_edit_registration_sequences!, except: %i[index show]
    helper_method :can_edit_registration_sequences?

    def index
      @draft = current_organization.registration_sequences.draft.first if can_edit_registration_sequences?
      @active = RegistrationSequence.active_for(current_organization)
      @previous = current_organization.registration_sequences.archived.order(end_at: :desc).to_a
    end

    # The faked registrant walk-through, one screen (?page=) per rule page plus the review
    # they end on. page is 1-indexed (Pagy); the preview component's index is 0-based.
    def show
      @registration_sequence = current_organization.registration_sequences.find(params[:id])
      return raise_do_not_have_access! if @registration_sequence.draft? && !can_edit_registration_sequences?

      screen_count = BikeServices::Register.acknowledgment_step_count(@registration_sequence)
      @preview_pagy = Pagy::Offset.new(count: screen_count, limit: 1, page: permitted_page(max: screen_count))
    end

    # Manage the draft's pages (add / reorder / edit) and its sequence-wide settings
    def edit
      @registration_sequence = find_draft
    end

    # The settings shared by every page: the FAQ link and the final acknowledgment
    def update
      @registration_sequence = find_draft
      if @registration_sequence.update(permitted_params)
        flash[:success] = "Registration sequence updated"
        redirect_to edit_organization_registration_sequence_path(organization_id: current_organization.to_param, id: @registration_sequence.id)
      else
        flash.now[:error] = @registration_sequence.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    # Opens the draft the org manages, cloning the live sequence (or the template) on first edit
    def create
      draft = RegistrationSequence.draft_for(current_organization)
      redirect_to edit_organization_registration_sequence_path(organization_id: current_organization.to_param, id: draft.id)
    end

    # Throw the draft away to start over; the live sequence is untouched
    def destroy
      find_draft.discard_draft!
      flash[:success] = "Draft discarded"
      redirect_to organization_registration_sequences_path(organization_id: current_organization.to_param)
    end

    private

    def find_draft
      current_organization.registration_sequences.draft.find(params[:id])
    end

    def permitted_params
      params.require(:registration_sequence).permit(:faq_url, :acknowledgment_text)
    end

    # Superusers can view regardless; org admins/members need the feature flag
    def ensure_access_to_registration_sequences!
      return unless ensure_current_organization!
      return true if current_organization.enabled?("registration_sequences") || current_user.superuser?

      raise_do_not_have_access!
    end

    def ensure_access_to_edit_registration_sequences!
      return true if can_edit_registration_sequences?

      raise_do_not_have_access!
    end

    def can_edit_registration_sequences?
      current_organization.enabled?("registration_sequences_edit") || current_user.superuser?
    end
  end
end
