module Organized
  class RegistrationSequencePagesController < Organized::AdminController
    before_action :ensure_access_to_registration_sequences!
    before_action :find_draft, only: %i[create]
    before_action :find_page, only: %i[edit update destroy]

    # Adds a blank page to the draft, then opens it for editing
    def create
      page = @draft.registration_sequence_pages.create!
      redirect_to edit_page_path(page)
    end

    def edit
    end

    # A position reorders the page (drag-and-drop on the show page); otherwise it's a field edit
    def update
      if params[:position].present?
        @draft.reorder_page!(@page, params[:position].to_i)
        head :ok
      elsif @page.update(permitted_parameters)
        flash[:success] = "Page updated"
        redirect_to sequence_path
      else
        flash[:error] = "Unable to update: #{@page.errors.full_messages.to_sentence}"
        render :edit
      end
    end

    def destroy
      @page.destroy
      flash[:success] = "Page removed"
      redirect_to sequence_path
    end

    private

    # Superusers can view regardless; org admins/members need the feature flag
    def ensure_access_to_registration_sequences!
      return unless ensure_current_organization!
      return true if current_organization.enabled?("registration_sequences") || current_user.superuser?

      raise_do_not_have_access!
    end

    def find_draft
      @draft = current_organization.registration_sequences.draft.find(params[:registration_sequence_id])
    end

    # Pages are only editable on the org's draft sequence
    def find_page
      @page = RegistrationSequencePage
        .where(registration_sequence: current_organization.registration_sequences.draft)
        .find(params[:id])
      @draft = @page.registration_sequence
    end

    def sequence_path
      edit_organization_registration_sequence_path(organization_id: current_organization.to_param, id: @draft.id)
    end

    def edit_page_path(page)
      edit_organization_registration_sequence_page_path(organization_id: current_organization.to_param, id: page.id)
    end

    def permitted_parameters
      params.require(:registration_sequence_page).permit(:title, :subtitle, :image, :body)
    end
  end
end
