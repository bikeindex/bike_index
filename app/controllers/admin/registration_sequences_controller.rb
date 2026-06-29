module Admin
  class RegistrationSequencesController < Admin::BaseController
    include Binxtils::SortableTable

    before_action :find_registration_sequence, only: %i[show update]

    def index
      @per_page = permitted_per_page(default: 50)
      @pagy, @collection = pagy(:countish,
        matching_registration_sequences.includes(:organization, :registration_sequence_pages)
          .reorder("registration_sequences.#{sort_column} #{sort_direction}"),
        limit: @per_page,
        page: permitted_page)
    end

    def show
    end

    # Authorizes the draft to become active (and ends the prior active)
    def update
      if @registration_sequence.make_active!
        flash[:success] = "Registration sequence is now active"
        redirect_to admin_registration_sequences_path
      else
        flash[:error] = "Unable to make active - the draft needs at least one page"
        redirect_to admin_registration_sequence_path(@registration_sequence)
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

    private

    def find_registration_sequence
      @registration_sequence = RegistrationSequence.find(params[:id])
    end
  end
end
