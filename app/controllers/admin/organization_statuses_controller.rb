# frozen_string_literal: true

class Admin::OrganizationStatusesController < Admin::BaseController
  include SortableTable

  WITH_POS_GRAPH_PARAMS = {search_pos_kind: "not_no_pos", render_chart: true}.freeze

  def index
    @per_page = permitted_per_page(default: 10)
    @pagy, @organization_statuses =
      pagy(:countish, matching_organization_statuses
        .reorder("organization_statuses.#{sort_column} #{sort_direction}"), limit: @per_page, page: permitted_page)
  end

  helper_method :matching_organization_statuses_untimed, :matching_organization_statuses, :grouped_pos_kinds, :humanize_pos_kind

  private

  def sortable_columns
    %w[start_at end_at organization_id pos_kind kind created_at organization_deleted_at].freeze
  end

  def earliest_period_date
    OrganizationStatus.minimum(:start_at) || Time.current - 1.day
  end

  def grouped_pos_kinds
    %w[not_no_pos broken_pos without_pos with_pos].freeze
  end

  def humanize_pos_kind(kind)
    if kind == "all"
      "All POS kinds"
    elsif kind == "not_no_pos"
      "Any POS kind (all but no_pos)"
    else
      kind&.humanize
    end
  end

  def permitted_pos_kinds
    Organization.pos_kinds + grouped_pos_kinds
  end

  def permitted_kinds
    Organization.kinds + ["not_bike_shop"]
  end

  # Needs to be a separate method so :at_time can be called on it
  def matching_organization_statuses_untimed
    organization_statuses = OrganizationStatus.all

    if current_organization.present?
      organization_statuses = organization_statuses.where(organization_id: current_organization.id)
    end

    if Binxtils::InputNormalizer.boolean(params[:search_current])
      @current = true
      organization_statuses = organization_statuses.current
    end

    if Binxtils::InputNormalizer.boolean(params[:search_ended])
      @ended = true
      organization_statuses = organization_statuses.ended
    end

    if Binxtils::InputNormalizer.boolean(params[:search_deleted])
      @deleted = true
      organization_statuses = organization_statuses.deleted
    end

    if permitted_pos_kinds.include?(params[:search_pos_kind])
      @pos_kind = params[:search_pos_kind]
      organization_statuses = organization_statuses.public_send(@pos_kind)
    else
      @pos_kind = "all"
    end

    if permitted_kinds.include?(params[:search_kind])
      @kind = params[:search_kind]
      organization_statuses = organization_statuses.public_send(@kind)
    else
      @kind = "all"
    end
    organization_statuses
  end

  def matching_organization_statuses
    @time_range_column = sort_column if %w[end_at created_at deleted_at].include?(sort_column)
    @time_range_column ||= "start_at"
    matching_organization_statuses_untimed.where(@time_range_column => @time_range)
  end
end
