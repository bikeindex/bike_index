class Admin::SocialAccountsController < Admin::BaseController
  include SortableTable

  before_action :find_social_account, only: %i[show edit update destroy check_credentials]

  def index
    @social_accounts = matching_social_accounts
      .reorder(sort_column + " " + sort_direction)
  end

  def show
  end

  def edit
  end

  def update
    if @social_account.update(permitted_parameters)
      if Binxtils::InputNormalizer.boolean(params[:check_credentials])
        @social_account.reload
        @social_account.check_credentials
      end
      flash[:notice] = "Social account saved!"
      redirect_to admin_social_account_url(@social_account)
    else
      render action: :edit
    end
  end

  def destroy
    if @social_account.present? && @social_account.destroy
      flash[:info] = "Social account deleted."
      redirect_to admin_social_accounts_url
    else
      flash[:error] = "Could not delete social account."
      redirect_to edit_admin_social_account_url(@social_account)
    end
  end

  def check_credentials
    @social_account.check_credentials
    redirect_to admin_social_account_url(@social_account)
  end

  private

  def sortable_columns
    %w[screen_name created_at email language country city last_error_at national]
  end

  def permitted_parameters
    params.require(:social_account).permit(
      :active,
      :address_string,
      :append_block,
      :city,
      :consumer_key,
      :consumer_secret,
      :country,
      :default,
      :language,
      :latitude,
      :longitude,
      :national,
      :neighborhood,
      :screen_name,
      :state,
      :user_secret,
      :user_token
    )
  end

  def matching_social_accounts
    if sort_column == "last_error_at" # If sorting by last_error_at, show the error
      (sort_direction == "desc") ? SocialAccount.errored : SocialAccount.where(last_error_at: nil)
    elsif sort_column == "national" # If national, show only national one direction, only non the other
      SocialAccount.where(national: sort_direction == "asc")
    else
      SocialAccount
    end
  end

  def find_social_account
    @social_account = SocialAccount.find(params[:id])
  end
end
