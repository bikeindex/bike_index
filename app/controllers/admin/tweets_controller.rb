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
    if @tweet.imported_tweet?
      redirect_to edit_admin_tweet_path(params[:id])
      nil
    end
  end

  def edit
    unless @tweet.imported_tweet?
      redirect_to admin_tweet_path(params[:id])
      nil
    end
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
    @tweet ||= Tweet.new(kind: "app_tweet")
  end

  def create
    @tweet = Tweet.new(permitted_parameters)
    if @tweet.kind == "imported_tweet"
      @tweet.twitter_account_id = nil
      @tweet.body = nil # Blank the attributes that may have been accidentally passed
      @tweet.twitter_response = fetch_twitter_response(@tweet.twitter_id)
    elsif @tweet.kind == "app_tweet"
      @tweet.twitter_id = nil
      @tweet.save
      if @tweet.id.present?
        @tweet.send_tweet
        retweet_accounts.each { |twitter_account| @tweet.retweet_to_account(twitter_account) }
      end
    else
      raise StandardError, "Don't know how to create tweet with kind: '#{@tweet.kind}'"
    end
    if @tweet.id.present?
      redirect_to edit_admin_tweet_url(id: @tweet.id)
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

  helper_method :matching_tweets, :permitted_search_kinds

  private

  def sortable_columns
    %w[created_at twitter_account_id kind]
  end

  def permitted_search_kinds
    %w[all not_stolen] + Tweet.kinds
  end

  def matching_tweets
    tweets = Tweet
    tweets = tweets.excluding_retweets unless ParamsNormalizer.boolean(params[:search_retweet])
    @search_kind = permitted_search_kinds.include?(params[:search_kind]) ? params[:search_kind] : "all"
    tweets = tweets.send(@search_kind) unless @search_kind == "all"

    if params[:search_twitter_account_id].present?
      @twitter_account = TwitterAccount.friendly_find(params[:search_twitter_account_id])
      tweets = tweets.where(twitter_account_id: @twitter_account.id) if @twitter_account.present?
    end
    tweets = tweets.admin_search(params[:query]) if params[:query].present?
    tweets.where(created_at: @time_range)
  end

  def permitted_parameters
    params.require(:tweet).permit(:twitter_id, :body_html, :image, :alignment, :body, :twitter_account_id,
      :remote_image_url, :remove_image, :kind)
  end

  def find_tweet
    @tweet ||= Tweet.friendly_find(params[:id])
    return @tweet if @tweet.present?
    raise ActiveRecord::RecordNotFound
  end

  def fetch_twitter_response(tweet_id)
    TwitterAccount.default_account.status(tweet_id).to_json
  end

  def retweet_accounts
    (params[:twitter_account_ids] || []).map { |id| TwitterAccount.friendly_find(id) }
  end
end
