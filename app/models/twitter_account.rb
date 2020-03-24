class TwitterAccount < ApplicationRecord
  include Geocodeable

  has_many :tweets, dependent: :destroy

  validates \
    :consumer_key,
    :consumer_secret,
    :user_secret,
    :user_token,
    :screen_name,
    presence: true

  validates :screen_name, uniqueness: true

  before_save :reverse_geocode, if: -> { !skip_geocoding? && latitude.present? && (state.blank? || state_changed?) }
  before_save :fetch_account_info

  scope :active, -> { where(active: true) }
  scope :national, -> { active.where(national: true) }
  scope :errored, -> { where.not(last_error_at: nil) }

  reverse_geocoded_by :latitude, :longitude do |account, results|
    if (geo = results.first)
      account.country = geo.country
      account.city = geo.city
      account.state = geo.state_code
      account.neighborhood = geo.neighborhood
    end
  end

  def self.fuzzy_screen_name_find(name)
    return if name.blank?
    where("lower(screen_name) = ?", name.downcase.strip).first
  end

  def self.default_account
    where(default: true).first || national.first
  end

  def self.default_account_for_country(country)
    national.where(country: country).first || default_account
  end

  def self.find_or_create_from_twitter_oauth(info)
    attrs = attrs_from_user_info(info)
    twitter_account = find_or_initialize_by(screen_name: attrs.delete(:screen_name))
    twitter_account.update(attrs)
    twitter_account
  end

  def self.attrs_from_user_info(info)
    {
      screen_name: info["info"]["nickname"],
      address: info["info"]["location"],
      consumer_key: ENV["TWITTER_CONSUMER_KEY"],
      consumer_secret: ENV["TWITTER_CONSUMER_SECRET"],
      user_token: info["credentials"]["token"],
      user_secret: info["credentials"]["secret"],
    }
  end

  def twitter_account_url
    "https://twitter.com/#{screen_name}"
  end

  def fetch_account_info
    return twitter_account_url if twitter_account_info.present?
    self.twitter_account_info = twitter_user
    self.created_at = TimeParser.parse(twitter_account_info["created_at"])
    twitter_account_info
  end

  def twitter_user
    @twitter_user ||= twitter_client.user(screen_name).to_h
  end

  def account_info_name
    return if twitter_account_info.blank?
    twitter_account_info["name"]
  end

  def account_info_image
    return if twitter_account_info.blank?
    twitter_account_info["profile_image_url_https"]
  end

  def set_error(message)
    update(last_error: message, last_error_at: Time.current)
  end

  def clear_error
    update(last_error: nil, last_error_at: nil)
  end

  def errored?
    last_error_at.present?
  end

  def check_credentials
    clear_error
    twitter_client.verify_credentials
  rescue Twitter::Error::Unauthorized, Twitter::Error::Forbidden => err
    set_error(err.message)
  end

  def tweet(text, photo = nil, **opts)
    return unless text.present?

    if photo.present?
      twitter_client.update_with_media(text, photo, opts)
    else
      twitter_client.update(text, opts)
    end
  rescue Twitter::Error::Unauthorized, Twitter::Error::Forbidden => err
    set_error(err.message)
    return
  end

  def retweet(tweet_id)
    return unless tweet_id.present?

    twitter_client.retweet(tweet_id).first
  rescue Twitter::Error::Unauthorized, Twitter::Error::Forbidden => err
    set_error(err.message)
    return
  end

  private

  def twitter_client
    @twitter_client ||= Twitter::REST::Client.new do |config|
      config.consumer_key = consumer_key
      config.consumer_secret = consumer_secret
      config.access_token = user_token
      config.access_token_secret = user_secret
    end
  end
end
