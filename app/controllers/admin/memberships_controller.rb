# frozen_string_literal: true

class Admin::MembershipsController < Admin::BaseController
  include SortableTable

  before_action :find_membership, only: %i[show update]

  def index
    @per_page = params[:per_page] || 50
    @pagy, @collection = pagy(
      matching_memberships.includes(:user, :creator, :stripe_subscriptions).reorder("memberships.#{sort_column} #{sort_direction}"),
      limit: @per_page
    )
  end

  def new
    @membership = Membership.new
    @membership.set_calculated_attributes # Sets start_at and level

    if params[:user_id].present?
      user = User.find_by(id: params[:user_id])
      @membership.user_email = user.email if user.present?
    end
  end

  def create
    @membership = Membership.new(permitted_create_parameters.merge(creator: current_user))
    if @membership.save
      flash[:success] = "Membership Created!"
      redirect_to admin_membership_url(@membership)
    else
      render action: :new
    end
  end

  def show
    @payments = @membership.payments
    @stripe_subscriptions = @membership.stripe_subscriptions
  end

  def edit
    redirect_to admin_membership_path
  end

  def update
    if InputNormalizer.boolean(params[:update_from_stripe])
      if @membership.update_from_stripe!
        flash[:success] = "Updated membership from Stripe successfully"
      end
      redirect_back(fallback_location: admin_membership_url(@membership)) && return
    end

    if @membership.stripe_managed?
      flash[:error] = "Stripe subscriptions must be edited on stripe"
      redirect_back(fallback_location: admin_membership_url(@membership)) && return
    end

    if @membership.update(permitted_update_parameters)
      flash[:success] = "Membership Saved!"
      redirect_to admin_membership_url(@membership)
    else
      render action: :show
    end
  end

  helper_method :matching_memberships, :searchable_levels, :searchable_statuses, :searchable_managers

  def searchable_statuses
    Membership.statuses.keys
  end

  def searchable_levels
    Membership.levels.keys
  end

  def searchable_managers
    %w[stripe_managed admin_managed].freeze
  end

  protected

  def sortable_columns
    %w[created_at start_at end_at updated_at level user_id].freeze
  end

  def earliest_period_date
    Time.at(1738389600) # 2025-02-1
  end

  def permitted_create_parameters
    params.require(:membership).permit(:user_email, :level, :start_at, :end_at)
  end

  def permitted_update_parameters
    params.require(:membership).permit(:level, :start_at, :end_at)
  end

  def find_membership
    @membership = Membership.find(params[:id])
  end

  def matching_memberships
    memberships = Membership.all
    @status = searchable_statuses.include?(params[:search_status]) ? params[:search_status] : nil
    memberships = memberships.where(status: @status) if @status.present?

    @level = searchable_levels.include?(params[:search_level]) ? params[:search_level] : nil
    memberships = memberships.where(level: @level) if @level.present?

    @manager = searchable_managers.include?(params[:search_manager]) ? params[:search_manager] : nil
    memberships = memberships.send(@manager) if @manager.present?

    if params[:user_id].present?
      @user = User.unscoped.friendly_find(params[:user_id])
      memberships = memberships.where(user_id: @user.id) if @user.present?
    end

    @time_range_column = sort_column if %w[start_at end_at updated_at].include?(sort_column)
    @time_range_column ||= "created_at"
    memberships.where(@time_range_column => @time_range)
  end
end
