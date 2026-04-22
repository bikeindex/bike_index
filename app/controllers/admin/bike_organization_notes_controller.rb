# frozen_string_literal: true

class Admin::BikeOrganizationNotesController < Admin::BaseController
  include Binxtils::SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @collection = pagy(:countish,
      matching_bike_organization_notes.includes(:user, :bike, :organization).reorder(sortable_opts),
      limit: @per_page,
      page: permitted_page)
  end

  def show
    @bike_organization_note = BikeOrganizationNote.find(params[:id])
  end

  helper_method :matching_bike_organization_notes

  private

  def sortable_columns
    %w[created_at updated_at user_id bike_id organization_id].freeze
  end

  def sortable_opts
    "bike_organization_notes.#{sort_column} #{sort_direction}"
  end

  def earliest_period_date
    BikeOrganizationNote.minimum(:created_at) || Time.current
  end

  def matching_bike_organization_notes
    bike_organization_notes = BikeOrganizationNote.all

    if params[:user_id].present?
      bike_organization_notes = bike_organization_notes.where(user_id: user_subject&.id || params[:user_id])
    end

    if params[:search_organization_id].present?
      bike_organization_notes = bike_organization_notes.where(organization_id: params[:search_organization_id])
    end

    if params[:search_bike_id].present?
      bike_organization_notes = bike_organization_notes.where(bike_id: params[:search_bike_id])
    end

    @time_range_column = sort_column if %w[updated_at].include?(sort_column)
    @time_range_column ||= "created_at"
    bike_organization_notes.where(@time_range_column => @time_range)
  end
end
