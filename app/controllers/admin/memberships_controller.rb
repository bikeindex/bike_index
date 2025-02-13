class Admin::MembershipsController < Admin::BaseController
  include SortableTable

  before_action :find_membership, only: %i[show update]
  before_action :set_period, only: %i[index]

  def index
    @per_page = params[:per_page] || 50
    @pagy, @memberships = pagy(
      matching_memberships.includes(:user, :creator, :stripe_subscriptions).reorder("memberships.#{sort_column} #{sort_direction}"),
      limit: @per_page
    )
  end

  def new
    @membership = Membership.new
    @membership.set_calculated_attributes # Sets start_at and kind

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
  end

  def update
    if @membership.stripe_managed?
      flash[:error] = "Stripe subscriptions must be edited on stripe"
      redirect_back(fallback_location: admin_memberships_url) && return
    end

    if @membership.update(permitted_update_parameters)
      flash[:success] = "Membership Saved!"
      redirect_to admin_membership_url(@membership)
    else
      render action: :edit
    end
  end

  protected

  def sortable_columns
    %w[created_at start_at end_at updated_at kind user_id]
  end

  def permitted_create_parameters
    params.require(:membership).permit(:user_email, :kind, :end_at)
  end

  def permitted_update_parameters
    params.require(:membership).permit(:kind, :start_at, :end_at)
  end

  def find_membership
    @membership = Membership.find(params[:id])
  end

  def matching_memberships
    memberships = Membership.all
    @activeness = %w[active inactive].include?(params[:search_activeness]) ? params[:search_activeness] : nil
    memberships = memberships.send(@activeness) if @activeness.present?
    if params[:user_id].present?
      @user = User.unscoped.friendly_find(params[:user_id])
      memberships = memberships.where(user_id: @user.id) if @user.present?
    end

    @time_range_column = sort_column if %w[start_at end_at updated_at].include?(sort_column)
    @time_range_column ||= "created_at"
    memberships.where(@time_range_column => @time_range)
  end
end
