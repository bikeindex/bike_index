module Admin
  class RegistrationSequencesController < Admin::BaseController
    include Binxtils::SortableTable

    before_action :find_registration_sequence, only: %i[show preview edit]
    # Activation freezes a sequence, so the actions that change one only ever find a draft
    before_action :find_draft, only: %i[update destroy]

    def index
      # The sequences organizations' drafts are cloned from, reachable without hunting the
      # table for them. Each kind's draft when there is one - that's what there is to do to it
      @templates = ::RegistrationSequence::KINDS.index_with do |kind|
        ::RegistrationSequence.existing_draft_for(nil, kind:) || ::RegistrationSequence.active_template(kind:)
      end
      @per_page = permitted_per_page(default: 50)
      @pagy, @collection = pagy(:countish,
        matching_registration_sequences.includes(:organization, :registration_sequence_pages)
          .reorder("registration_sequences.#{sort_column} #{sort_direction}"),
        limit: @per_page,
        page: permitted_page)
    end

    # The sequence's pages and settings, read-only - editing it is #edit
    def show
    end

    # The faked registrant walk-through, one screen (?page=) per rule page plus the review
    # they end on. page is 1-indexed (Pagy); the preview component's index is 0-based.
    def preview
      screen_count = BikeServices::Register.acknowledgment_step_count(@registration_sequence)
      @preview_pagy = Pagy::Offset.new(count: screen_count, limit: 1, page: permitted_page(max: screen_count))
    end

    # An activated sequence renders read-only - acknowledgments reference what it says
    def edit
    end

    # An activate param makes the draft live; otherwise it's the settings shared by every
    # page, the FAQ link and the final acknowledgment
    def update
      if params[:activate].present?
        make_active
      elsif @registration_sequence.update(permitted_params)
        flash[:success] = "Registration sequence updated"
        redirect_to RegistrationSequencePaths.edit(@registration_sequence, admin: true)
      else
        flash.now[:error] = @registration_sequence.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    # Opens the draft, cloning the live sequence on first edit. No organization_id is the
    # template - friendly_find! so a typo 404s rather than opening the template's draft
    def create
      organization = ::Organization.friendly_find!(params[:organization_id]) if params[:organization_id].present?
      kind = ::RegistrationSequence.permitted_kind(params[:kind])
      redirect_to RegistrationSequencePaths.edit(::RegistrationSequence.draft_for(organization, kind:), admin: true)
    end

    # Throw the draft away to start over; the live sequence is untouched
    def destroy
      @registration_sequence.discard_draft!
      flash[:success] = "Draft discarded"
      redirect_to RegistrationSequencePaths.index(@registration_sequence, admin: true)
    end

    helper_method :matching_registration_sequences, :searchable_statuses, :searchable_kinds

    def searchable_statuses
      ::RegistrationSequence::STATUSES
    end

    def searchable_kinds
      ::RegistrationSequence::KINDS
    end

    protected

    def sortable_columns
      %w[created_at updated_at start_at end_at organization_id].freeze
    end

    def earliest_period_date
      Time.at(1780272000) # 2026-06-01 - registration sequences introduced
    end

    def matching_registration_sequences
      registration_sequences = ::RegistrationSequence.all
      @status = searchable_statuses.include?(params[:search_status]) ? params[:search_status] : nil
      registration_sequences = registration_sequences.for_status(@status) if @status.present?

      @kind = searchable_kinds.include?(params[:search_kind]) ? params[:search_kind] : nil
      registration_sequences = registration_sequences.where(kind: @kind) if @kind.present?

      if params[:organization_id].present?
        registration_sequences = registration_sequences.where(organization_id: params[:organization_id])
      end

      @time_range_column = sort_column if %w[updated_at].include?(sort_column)
      @time_range_column ||= "created_at"
      registration_sequences.where(@time_range_column => @time_range)
    end

    def find_registration_sequence
      @registration_sequence = ::RegistrationSequence.includes(:organization, :registration_sequence_pages)
        .find(params[:id])
    end

    def find_draft
      @registration_sequence = ::RegistrationSequence.draft.find(params[:id])
    end

    # Archives the sequence it supersedes. Organizations ask us to do this for them -
    # their own screens only get them as far as a finished draft
    def make_active
      if @registration_sequence.make_active!
        flash[:success] = "#{@registration_sequence.display_name} registration sequence is live"
        redirect_to RegistrationSequencePaths.sequence(@registration_sequence, admin: true)
      else
        flash[:error] = "Unable to activate - every page needs a title and rules"
        redirect_to RegistrationSequencePaths.edit(@registration_sequence, admin: true)
      end
    end

    def permitted_params
      params.require(:registration_sequence).permit(:faq_url, :acknowledgment_text)
    end
  end
end
