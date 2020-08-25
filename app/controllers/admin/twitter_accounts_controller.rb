class Admin::TwitterAccountsController < Admin::BaseController
  include SortableTable
  before_action :find_twitter_account, only: %i[show edit update destroy check_credentials]
  skip_before_action :require_index_admin!, only: %(create)

  def index
    @twitter_accounts = matching_twitter_accounts.reorder(sort_column + " " + sort_direction)
  end

  def show
  end

  def edit
  end

  def update
    if @twitter_account.update_attributes(permitted_parameters)
      if ParamsNormalizer.boolean(params[:check_credentials])
        @twitter_account.reload
        @twitter_account.check_credentials
      end
      flash[:notice] = "Twitter account saved!"
      redirect_to admin_twitter_account_url(@twitter_account)
    else
      render action: :edit
    end
  end

  def create
    twitter_account =
      TwitterAccount.find_or_create_from_twitter_oauth(request.env["omniauth.auth"])

    if twitter_account.persisted?
      twitter_account.check_credentials
      flash[:notice] = "Twitter account #{twitter_account.screen_name} is persisted."
      redirect_to admin_twitter_account_url(twitter_account)
    else
      flash[:error] = twitter_account.errors.full_messages.to_sentence
      redirect_to admin_twitter_accounts_url
    end
  end

  def destroy
    if @twitter_account.present? && @twitter_account.destroy
      flash[:info] = "Twitter account deleted."
      redirect_to admin_twitter_accounts_url
    else
      flash[:error] = "Could not delete Twitter account."
      redirect_to edit_admin_twitter_account_url(@twitter_account)
    end
  end

  def check_credentials
    @twitter_account.check_credentials
    redirect_to admin_twitter_account_url(@twitter_account)
  end

  private

  def sortable_columns
    %w[screen_name created_at email language country city last_error_at national]
  end

  def permitted_parameters
    params.require(:twitter_account).permit(
      :active,
      :address,
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

  def matching_twitter_accounts
    if sort_column == "last_error_at" # If sorting by last_error_at, show the error
      sort_direction == "desc" ? TwitterAccount.errored : TwitterAccount.where(last_error_at: nil)
    elsif sort_column == "national" # If national, show only national one direction, only non the other
      TwitterAccount.where(national: sort_direction == "asc")
    else
      TwitterAccount
    end
  end

  def find_twitter_account
    @twitter_account = TwitterAccount.find(params[:id])
  end
end
