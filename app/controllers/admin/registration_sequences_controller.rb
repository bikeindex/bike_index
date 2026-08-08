module Admin
  class RegistrationSequencesController < Admin::BaseController
    include Binxtils::SortableTable

    def index
      @per_page = permitted_per_page(default: 50)
      @pagy, @collection = pagy(:countish,
        matching_registration_sequences.includes(:organization, :registration_sequence_pages)
          .reorder("registration_sequences.#{sort_column} #{sort_direction}"),
        limit: @per_page,
        page: permitted_page)
    end

    # The template every organization's first draft is cloned from. It's created on demand,
    # so this redirects rather than the index linking to an id that might not exist yet
    def template
      redirect_to edit_admin_registration_sequence_path(RegistrationSequence.template)
    end

    # The faked registrant walk-through, one screen (?page=) per rule page plus the review
    # they end on. page is 1-indexed (Pagy); the preview component's index is 0-based.
    def show
      @registration_sequence = RegistrationSequence.find(params[:id])
      screen_count = BikeServices::Register.acknowledgment_step_count(@registration_sequence)
      @preview_pagy = Pagy::Offset.new(count: screen_count, limit: 1, page: permitted_page(max: screen_count))
    end

    # Manage the sequence's pages and its sequence-wide settings. An activated sequence
    # renders read-only - acknowledgments reference it, so it can't change
    def edit
      @registration_sequence = RegistrationSequence.find(params[:id])
    end

    # The settings shared by every page: the FAQ link and the final acknowledgment
    def update
      @registration_sequence = RegistrationSequence.editable.find(params[:id])
      if @registration_sequence.update(permitted_params)
        flash[:success] = "Registration sequence updated"
        redirect_to edit_admin_registration_sequence_path(@registration_sequence)
      else
        flash.now[:error] = @registration_sequence.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    helper_method :matching_registration_sequences, :searchable_statuses

    def searchable_statuses
      RegistrationSequence::STATUSES
    end

    protected

    def sortable_columns
      %w[created_at updated_at start_at end_at organization_id].freeze
    end

    def earliest_period_date
      Time.at(1780272000) # 2026-06-01 - registration sequences introduced
    end

    def matching_registration_sequences
      registration_sequences = RegistrationSequence.all
      @status = searchable_statuses.include?(params[:search_status]) ? params[:search_status] : nil
      registration_sequences = registration_sequences.for_status(@status) if @status.present?

      if params[:organization_id].present?
        registration_sequences = registration_sequences.where(organization_id: params[:organization_id])
      end

      @time_range_column = sort_column if %w[updated_at].include?(sort_column)
      @time_range_column ||= "created_at"
      registration_sequences.where(@time_range_column => @time_range)
    end

    def permitted_params
      params.require(:registration_sequence).permit(:faq_url, :acknowledgment_text)
    end
  end
end
