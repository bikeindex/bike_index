module Organized
  class RegistrationSequencePagesController < Organized::AdminController
    before_action :find_draft
    before_action :find_page, only: %i[edit update destroy]

    # Adds a blank page to the draft, then opens it for editing
    def create
      page = @draft.registration_sequence_pages.create!
      redirect_to edit_page_path(page)
    end

    def edit
    end

    def update
      if @page.update(permitted_parameters)
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

    # Drag-and-drop reorder: page_ids is the new order
    def sort
      @draft.reorder_pages!(params[:page_ids])
      head :ok
    end

    private

    # Pages are only editable on the draft
    def find_draft
      @draft = current_organization.registration_sequences.draft.find(params[:registration_sequence_id])
    end

    def find_page
      @page = @draft.registration_sequence_pages.find(params[:id])
    end

    def sequence_path
      organization_registration_sequence_path(organization_id: current_organization.to_param, id: @draft.id)
    end

    def edit_page_path(page)
      edit_organization_registration_sequence_page_path(organization_id: current_organization.to_param, registration_sequence_id: @draft.id, id: page.id)
    end

    def permitted_parameters
      params.require(:registration_sequence_page).permit(:title, :subtitle, :image, :body)
    end
  end
end
