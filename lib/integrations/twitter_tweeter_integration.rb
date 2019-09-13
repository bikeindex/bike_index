require "twitter"
require "geocoder"
require "tempfile"
require "open-uri"

class TwitterTweeterIntegration
  attr_accessor \
    :bike,
    :bike_photo_url,
    :city,
    :close_twitter_accounts,
    :max_char,
    :neighborhood,
    :retweets,
    :state,
    :stolen_record,
    :tweet

  def initialize(bike)
    self.bike = bike
    self.stolen_record = bike.current_stolen_record
    self.bike_photo_url = bike.public_images.first&.image_url
    self.close_twitter_accounts = stolen_record&.twitter_accounts_in_proximity
    self.city = stolen_record&.city
    self.state = stolen_record&.state&.abbreviation
    self.neighborhood = stolen_record&.neighborhood
  end

  # To manually send a tweet (e.g. if authentication failed)
  # TwitterTweeterIntegration.new(Bike.find_by_bike_index_bike_id(XXX)).create_tweet
  def create_tweet
    return unless stolen_record.present?

    update_str = build_bike_status
    update_opts = {
      lat: stolen_record.latitude,
      long: stolen_record.longitude,
      display_coordinates: "true",
    }

    near_twitter_account = close_twitter_accounts.first
    client = twitter_client_start(near_twitter_account)
    raise ArgumentError, "failed initializing Twitter client" if client.nil?

    posted_tweet = nil # If this isn't instantiated, it isn't accessible outside media block.

    begin
      if bike_photo_url.present?
        Tempfile.open("foto.jpg") do |foto|
          foto.binmode
          foto.write open(bike_photo_url).read
          foto.rewind
          posted_tweet = client.update_with_media(update_str, foto, update_opts)
        end
      else
        posted_tweet = client.update(update_str, update_opts)
      end
    rescue Twitter::Error::Unauthorized, Twitter::Error::Forbidden => err
      near_twitter_account.update(last_error: err.message)
    end

    self.tweet = Tweet.new(
      twitter_id: posted_tweet.id,
      twitter_account_id: close_twitter_accounts.first&.id,
      stolen_record_id: stolen_record&.id,
      twitter_response: posted_tweet.to_json,
    )

    if tweet.save
      near_twitter_account.update(last_error: nil)
    else
      near_twitter_account.update(last_error: tweet.errors.full_messages.to_sentence)
    end

    retweet(posted_tweet)
    tweet
  end

  def retweet(posted_tweet)
    self.retweets = [posted_tweet]

    close_twitter_accounts.each do |twitter_account|
      next if twitter_account.id.to_i == tweet.twitter_account_id.to_i
      client = twitter_client_start(twitter_account)
      begin
        # retweet returns an array even with scalar parameters
        posted_retweet = client.retweet(tweet.twitter_id).first
        next if posted_retweet.blank?

        retweets.push(posted_retweet)
        retweet = Tweet.new(
          twitter_id: posted_retweet.id,
          twitter_account_id: twitter_account.id,
          stolen_record_id: stolen_record.id,
          original_tweet_id: tweet.id,
        )

        if retweet.save
          twitter_account.update(last_error: nil)
        else
          twitter_account.update(last_error: retweet.errors.full_messages.to_sentence)
        end
      rescue Twitter::Error::Unauthorized, Twitter::Error::Forbidden => err
        twitter_account.update(last_error: err.message)
      end
    end

    retweets
  end

  def stolen_slug
    if bike.stolen?
      "STOLEN -"
    else
      "FOUND -"
    end
  end

  def compute_max_char
    # TODO store these constants in the database and update them once a day with
    # a REST client.configuration call
    #
    # spaces between slugs
    # max_char = tweet_length - https_length - at_screen_name.length - 3

    tweet_length = 140
    https_length = 23
    media_length = 23

    # spaces between slugs
    max = tweet_length - https_length - stolen_slug.size - 3
    max -= bike_photo_url ? media_length : 0

    max
  end

  def tweet_string(stolen_slug, bike_slug, url)
    "#{stolen_slug} #{bike_slug} #{url}"
  end

  def tweet_string_with_options(stolen_slug, bike_slug, url)
    ts = tweet_string(stolen_slug, bike_slug, url)

    if close_twitter_accounts&.first&.append_block.present?
      block = close_twitter_accounts.first.append_block
      ts << " #{block}" if (ts.length + block.length) < max_char
    end

    ts
  end

  # Perform the conditional text processing to create a reply string
  # that fits twitter's limits
  #
  # param bike [Hash] bike hash as delivered by BikeIndex that we're going to tweet about
  def build_bike_status
    self.max_char = compute_max_char

    location = ""
    if !close_twitter_accounts&.first&.default? && neighborhood.present?
      location = "in #{neighborhood}"
    elsif city.present? && state.present?
      location = "in #{city}, #{state}"
    end

    color = bike.frame_colors.first
    if color.start_with?("Silver")
      color.replace "Gray"
    elsif color.start_with?("Stickers")
      color.replace ""
    end

    manufacturer = bike.manufacturer.name
    model = bike.frame_model

    full_length =
      [color, model, manufacturer, location]
        .select(&:present?)
        .map(&:size)
        .sum + 3

    components =
      if full_length <= max_char
        [color, manufacturer, model, location]
      elsif full_length - color&.size.to_i - 1 <= max_char
        [manufacturer, model, location]
      elsif full_length - manufacturer&.size.to_i - 1 <= max_char
        [color, model, location]
      elsif full_length - model&.size.to_i - 1 <= max_char
        [color, manufacturer, location]
      elsif model&.size.to_i + 2 <= max_char
        ["a", model]
      elsif manufacturer&.size.to_i + 2 <= max_char
        ["a", manufacturer]
      elsif color&.size.to_i + 5 <= max_char
        [color, "bike"]
      else
        []
      end

    bike_slug = components.select(&:present?).join(" ")
    tweet_string_with_options(stolen_slug, bike_slug, bike_url(bike))
  end

  def twitter_client_start(twitter_account)
    return if twitter_account.blank?

    Twitter::REST::Client.new do |config|
      config.consumer_key = twitter_account[:consumer_key]
      config.consumer_secret = twitter_account[:consumer_secret]
      config.access_token = twitter_account[:user_token]
      config.access_token_secret = twitter_account[:user_secret]
    end
  end

  private

  def bike_url(bike)
    "https://bikeindex.org/bikes/#{bike.id}"
  end
end
