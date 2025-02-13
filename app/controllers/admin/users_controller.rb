class Admin::UsersController < Admin::BaseController
  include SortableTable

  before_action :find_user, only: [:show, :edit, :update, :destroy]

  def index
    @per_page = params[:per_page] || 25
    @pagy, @users = pagy(matching_users.reorder("users.#{sort_column} #{sort_direction}")
      .includes(:ownerships, :superuser_abilities, :payments, :user_emails, :organization_roles, :ambassador_tasks),
      limit: @per_page)
  end

  def show
    redirect_to edit_admin_user_url(@user&.id)
  end

  def edit
    # urls with user IDs rather than usernames are more helpful in superadmin
    if params[:id] == @user.username
      redirect_to edit_admin_user_path(@user.id)
    end
    calculate_user_bikes
  end

  def update
    if params[:force_merge_email].present?
      force_merge_users(params[:force_merge_email])
    else
      @user.name = params[:user][:name]
      @user.email = params[:user][:email]
      @user.superuser = params[:user][:superuser]
      @user.developer = params[:user][:developer] if current_user.developer? && params[:user].key?(:developer)
      @user.banned = params[:user][:banned]
      if @user.banned && permitted_ban_parameters[:reason].present?
        UserBan.create!(permitted_ban_parameters)
      end
      @user.username = params[:user][:username]
      @user.can_send_many_stolen_notifications = params[:user][:can_send_many_stolen_notifications]
      @user.phone = params[:user][:phone]
      if @user.save
        @user.update_auth_token("auth_token") if @user.banned? # Force reauthentication for the user
        @user.confirm(@user.confirmation_token) if params[:user][:confirmed]
        redirect_to admin_users_url, notice: "User Updated"
      else
        calculate_user_bikes
        render action: :edit
      end
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_users_url, notice: "User Deleted."
  end

  helper_method :matching_users

  protected

  def sortable_columns
    %w[created_at email updated_at deleted_at]
  end

  def earliest_period_date
    Time.at(1357912007)
  end

  def find_user
    @user = User.unscoped.username_friendly_find(params[:id])
    raise ActiveRecord::RecordNotFound unless @user.present?
  end

  def permitted_ban_parameters
    params.require(:user).permit(user_ban_attributes: %i[reason description])
      &.dig(:user_ban_attributes)
      &.merge(creator_id: current_user.id, user_id: @user.id)
  end

  def force_merge_users(email)
    email = EmailNormalizer.normalize(email)
    secondary_user = User.fuzzy_confirmed_or_unconfirmed_email_find(email)
    if secondary_user.present?
      if secondary_user.unconfirmed?
        secondary_user.confirm(secondary_user.confirmation_token)
        secondary_user.reload
      end
      @user.confirm(@user.confirmation_token) if @user.unconfirmed?

      user_email = @user.user_emails.find_by_email(email)
      # Manually confirm the user
      user_email.update(confirmation_token: nil) if user_email&.unconfirmed?
      user_email ||= @user.user_emails.create(email: email)
      if MergeAdditionalEmailJob.new.perform(user_email.id)
        flash[:success] = "User #{@user.display_name} merged with '#{email}'"
      else
        flash[:error] = "Unable to merge users!"
      end
    else
      flash[:error] = "Unable to find user with email: '#{email}', did not merge"
    end
    redirect_to admin_user_path(@user)
  end

  def matching_users
    @search_ambassadors = InputNormalizer.boolean(params[:search_ambassadors])
    @search_banned = InputNormalizer.boolean(params[:search_banned])
    @search_superusers = InputNormalizer.boolean(params[:search_superusers])
    @search_deleted = InputNormalizer.boolean(params[:search_deleted])
    @updated_at = InputNormalizer.boolean(params[:search_updated_at])
    @search_unconfirmed = InputNormalizer.boolean(params[:search_unconfirmed])
    @search_confirmed = @search_unconfirmed ? false : InputNormalizer.boolean(params[:search_confirmed])
    users = if current_organization.present?
      current_organization.users
    else
      User
    end
    users = users.only_deleted if @search_deleted
    users = users.ambassadors if @search_ambassadors
    users = users.superuser_abilities if @search_superusers
    users = users.banned if @search_banned
    users = users.unconfirmed if @search_unconfirmed
    users = users.confirmed if @search_confirmed

    users = users.admin_text_search(params[:query]) if params[:query].present?
    if params[:search_phone].present?
      users = users.search_phone(params[:search_phone])
    end
    if params[:search_domain].present?
      users = users.matching_domain(params[:search_domain])
    end

    @time_range_column = sort_column if %w[updated_at deleted_at].include?(sort_column)
    @time_range_column = nil if @time_range_column == "deleted_at" && !@search_deleted
    @time_range_column ||= "created_at"
    users.where(@time_range_column => @time_range)
  end

  def calculate_user_bikes
    # If the user has a bunch of bikes, it can cause timeouts. In those cases, use rough approximation
    bikes = @user.bikes
    @bikescount = @user.bikes.count
    @bikes = bikes.reorder(created_at: :desc).limit(10)
  end
end
