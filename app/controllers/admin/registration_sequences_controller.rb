module Admin
  class RegistrationSequencesController < Admin::BaseController
    before_action :find_registration_sequence, only: %i[show update]

    def index
      @registration_sequences = RegistrationSequence.draft
        .includes(:organization, :pages).order(updated_at: :desc)
    end

    def show
      @live = RegistrationSequence.live_for(@registration_sequence.organization)
    end

    # Authorizes the draft to become live (and archives the prior live)
    def update
      if @registration_sequence.make_live!(current_user)
        flash[:success] = "Registration sequence is now live"
        redirect_to admin_registration_sequences_path
      else
        flash[:error] = "Unable to make live - the draft needs at least one page"
        redirect_to admin_registration_sequence_path(@registration_sequence)
      end
    end

    private

    def find_registration_sequence
      @registration_sequence = RegistrationSequence.find(params[:id])
    end
  end
end
