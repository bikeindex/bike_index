module Organized
  class RegistrationSequencePagesController < Organized::AdminController
    before_action :ensure_access_to_edit_registration_sequences!
    before_action :find_draft, only: %i[new create]
    before_action :find_page, only: %i[edit update destroy]

    # A blank page to fill in; it's only persisted once it has a title and rules
    def new
      @page = @draft.registration_sequence_pages.new
      render :edit
    end

    def create
      @page = @draft.registration_sequence_pages.new(permitted_parameters)
      if @page.save
        flash[:success] = "Page added"
        redirect_to RegistrationSequencePaths.edit(@draft)
      else
        flash.now[:error] = "Unable to add: #{@page.errors.full_messages.to_sentence}"
        render :edit, status: :unprocessable_entity
      end
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
        # Back to this page so the refreshed preview is right there
        redirect_to RegistrationSequencePaths.edit_page(@page)
      else
        flash[:error] = "Unable to update: #{@page.errors.full_messages.to_sentence}"
        render :edit
      end
    end

    def destroy
      @page.destroy
      flash[:success] = "Page removed"
      redirect_to RegistrationSequencePaths.edit(@draft)
    end

    private

    # Every action here changes the draft, so the edit feature gates the whole controller
    def ensure_access_to_edit_registration_sequences!
      return unless ensure_current_organization!
      return true if current_organization.enabled?("registration_sequences_edit") || current_user.superuser?

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

    def permitted_parameters
      params.require(:registration_sequence_page).permit(:title, :heading, :subtitle, :image, :body, :organization_specific)
    end
  end
end
