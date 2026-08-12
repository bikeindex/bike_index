module Admin
  class RegistrationSequencePagesController < Admin::BaseController
    before_action :find_registration_sequence, only: %i[new create]
    before_action :find_page, only: %i[edit update destroy]

    # A blank page to fill in; it's only persisted once it has a title and rules
    def new
      @page = @registration_sequence.registration_sequence_pages.new
      render :edit
    end

    def create
      @page = @registration_sequence.registration_sequence_pages.new(permitted_parameters)
      if @page.save
        flash[:success] = "Page added"
        redirect_to RegistrationSequencePaths.edit(@registration_sequence, admin: true)
      else
        flash.now[:error] = "Unable to add: #{@page.errors.full_messages.to_sentence}"
        render :edit, status: :unprocessable_entity
      end
    end

    def edit
    end

    # A position reorders the page (drag-and-drop on the edit page); otherwise it's a field edit
    def update
      if params[:position].present?
        @registration_sequence.reorder_page!(@page, params[:position].to_i)
        head :ok
      elsif @page.update(permitted_parameters)
        flash[:success] = "Page updated"
        # Back to this page so the refreshed preview is right there
        redirect_to RegistrationSequencePaths.edit_page(@page, admin: true)
      else
        flash[:error] = "Unable to update: #{@page.errors.full_messages.to_sentence}"
        render :edit
      end
    end

    def destroy
      @page.destroy
      flash[:success] = "Page removed"
      redirect_to RegistrationSequencePaths.edit(@registration_sequence, admin: true)
    end

    private

    # Activation freezes a sequence and its pages, so only drafts are edited
    def find_registration_sequence
      @registration_sequence = ::RegistrationSequence.draft.find(params[:registration_sequence_id])
    end

    def find_page
      @page = ::RegistrationSequencePage.where(registration_sequence: ::RegistrationSequence.draft)
        .find(params[:id])
      @registration_sequence = @page.registration_sequence
    end

    def permitted_parameters
      params.require(:registration_sequence_page).permit(:title, :heading, :subtitle, :image, :body, :organization_specific)
    end
  end
end
