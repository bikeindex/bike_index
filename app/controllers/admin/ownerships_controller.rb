class Admin::OwnershipsController < Admin::BaseController
  include SortableTable

  before_action :find_ownership, except: [:index]

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @ownerships = pagy(:countish, matching_ownerships.reorder("ownerships.#{sort_column} #{sort_direction}")
      .includes(:bike, :organization, :creator, :user), limit: @per_page, page: permitted_page)
  end

  def show
    redirect_to edit_admin_ownership_path
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

  helper_method :matching_ownerships, :organization_kind_options

  private

  def sortable_columns
    %w[created_at updated_at creator_id owner_email]
  end

  def ownership_origins
    Ownership.origins + %w[only_initial]
  end

  def organization_kind_options
    %w[without_organization only_with_organization]
  end

  def matching_ownerships
    ownerships = Ownership.unscoped
    if organization_kind_options.include?(params[:search_organization_kind])
      @search_organization_kind = params[:search_organization_kind]
      ownerships = if @search_organization_kind == "without_organization"
        ownerships.where(organization_id: nil)
      else
        ownerships.where.not(organization_id: nil)
      end
    end
    ownerships = ownerships.where(organization_id: current_organization.id) if current_organization.present?

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
