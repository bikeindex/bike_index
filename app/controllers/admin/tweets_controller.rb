class Admin::TweetsController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]
  before_action :find_tweet, except: [:new, :create, :index]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @tweets = matching_tweets
        .includes(:twitter_account, :public_images, :stolen_record, :retweets, :original_tweet)
        .reorder(sort_column + " " + sort_direction)
        .page(page)
        .per(per_page)
  end

  def show
    redirect_to edit_admin_tweet_url
  end

  def edit
  end

  def update
    if @tweet.update_attributes(permitted_parameters)
      flash[:notice] = "Tweet saved!"
      redirect_to edit_admin_tweet_url
    else
      render action: :edit
    end
  end

  def new
    @tweet = Tweet.new
  end

  def create
    @tweet = Tweet.new(permitted_parameters)
    @tweet.twitter_response = fetch_twitter_response(@tweet.twitter_id)
    if @tweet.save
      redirect_to edit_admin_tweet_url(id: @tweet.twitter_id)
    else
      render action: :new
    end
  end

  def destroy
    if @tweet.present? && @tweet.destroy
      flash[:info] = "Tweet deleted."
      redirect_to admin_tweets_url
    else
      flash[:error] = "Could not delete tweet."
      redirect_to edit_admin_tweet_url(@tweet.id)
    end
  end

  helper_method :matching_tweets

  private

  def sortable_columns
    %w[created_at twitter_account_id]
  end

  def permitted_parameters
    params.require(:tweet).permit(:twitter_id, :body_html, :image, :alignment,
      :remote_image_url, :remove_image, :kind)
  end

  def find_tweet
    @tweet ||= Tweet.friendly_find(params[:id])
  end

  def fetch_twitter_response(tweet_id)
    TwitterClient.status(tweet_id).to_json
  end

  def matching_tweets
    tweets = Tweet.excluding_retweets
    if params[:search_kind] == "all"
      @search_kind = "all"
    else
      @search_kind = Tweet.kinds.include?(params[:search_kind]) ? params[:search_kind] : "not_stolen"
      tweets = tweets.send(@search_kind)
    end
    if params[:twitter_account_id].present?
      @twitter_account = TwitterAccount.friendly_find(params[:twitter_account_id])
      tweets = tweets.where(twitter_account_id: @twitter_account.id) if @twitter_account.present?
    end
    tweets = tweets.admin_search(params[:query]) if params[:query].present?
    tweets.where(created_at: @time_range)
  end
end
