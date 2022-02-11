class Admin::OwnershipsController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]
  before_action :find_ownership, except: [:index]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @ownerships = matching_ownerships.reorder("ownerships.#{sort_column} #{sort_direction}")
      .includes(:bike, :organization, :creator, :user)
      .page(page).per(per_page)
  end

  def edit
  end

  def update
    error_message = []
    if params[:ownership]
      if params[:ownership][:user_email].present?
        params[:ownership][:user_id] = User.friendly_find_id(params[:ownership].delete(:user_email))
        error_message << "No confirmed user with that User email!" unless params[:ownership][:user_id].present?
      end
      if params[:ownership][:creator_email].present?
        params[:ownership][:creator_id] = User.friendly_find_id(params[:ownership].delete(:creator_email))
        error_message << "No confirmed user with creator email!" unless params[:ownership][:creator_id].present?
      end
    end
    if error_message.blank? && params[:ownership].present? && @ownership.update(permitted_parameters)
      flash[:success] = "Ownership Saved!"
      redirect_to edit_admin_ownership_url(@ownership.id)
    else
      if error_message.present?
        flash[:error] = error_message.join(" ")
      else
        flash[:info] = "No information updated"
      end
      render action: :edit
    end
  end

  helper_method :matching_ownerships

  private

  def sortable_columns
    %w[created_at updated_at creator_id owner_email]
  end

  def ownership_origins
    Ownership.origins + %w[only_initial]
  end

  def matching_ownerships
    ownerships = Ownership.unscoped
    @search_origin = ownership_origins.include?(params[:search_origin]) ? params[:search_origin] : "all"
    unless @search_origin == "all"
      ownerships = if @search_origin == "only_initial"
        ownerships.initial
      else
        ownerships.where(origin: @search_origin)
      end
    end
    @time_range_column = sort_column if %w[updated_at].include?(sort_column)
    @time_range_column ||= "created_at"
    ownerships.where(@time_range_column => @time_range)
  end

  def find_ownership
    @ownership = Ownership.find(params[:id])
    @bike = Bike.unscoped.find(@ownership.bike_id)
    @users = User.all
  end

  def permitted_parameters
    params.require(:ownership).permit(:bike_id, :user_id, :owner_email, :creator_id, :current,
      :claimed, :example, :send_email, :user_hidden)
  end
end
