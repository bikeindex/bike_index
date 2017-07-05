class Admin::TweetsController < Admin::BaseController
  before_filter :find_tweet, except: [:new, :create, :index]
  def index
    @tweets = Tweet.order(created_at: :desc)
  end

  def show
    redirect_to edit_admin_tweet_url
  end

  def edit
  end

  def update
    if @tweet.update_attributes(permitted_parameters)
      flash[:notice] = 'Tweet saved!'
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

  private

  def permitted_parameters
    params.require(:tweet).permit(:twitter_id, :body_html, :image, :alignment,
                                  :remote_image_url, :remove_image)
  end

  def find_tweet
    @tweet ||= Tweet.friendly_find(params[:id])
  end

  def fetch_twitter_response(tweet_id)
    Twitter.status(tweet_id).to_json
  end
end
