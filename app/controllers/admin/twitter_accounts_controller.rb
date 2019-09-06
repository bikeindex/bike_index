class Admin::TwitterAccountsController < Admin::BaseController
  before_filter :find_twitter_account, only: %i[show edit update destroy]

  def index
    @twitter_accounts = TwitterAccount.order(created_at: :desc)
  end

  def show; end

  def new
    @twitter_account = TwitterAccount.new
  end

  def create
    @twitter_account = TwitterAccount.new(permitted_parameters)
    @twitter_account.twitter_account_info =
      TwitterClient.user(@twitter_account.screen_name).to_json

    if @twitter_account.save
      redirect_to admin_twitter_account_url(@twitter_account)
    else
      render action: :new
    end
  end

  def edit; end

  def update
    if @twitter_account.update_attributes(permitted_parameters)
      flash[:notice] = "Twitter account saved!"
      redirect_to admin_twitter_account_url(@twitter_account)
    else
      render action: :edit
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

  private

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
      :user_token,
    )
  end

  def find_twitter_account
    @twitter_account = TwitterAccount.find(params[:id])
  end
end
