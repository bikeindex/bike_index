require "twitter"
require "tempfile"
require "open-uri"

class Integrations::TwitterTweeter
  TWEET_LENGTH = 280
  MAX_RETWEET_COUNT = (ENV["MAX_RETWEET_COUNT"] || 3).to_i

  attr_accessor \
    :bike,
    :bike_photo_url,
    :city,
    :close_twitter_accounts,
    :max_char,
    :nearest_twitter_account,
    :neighborhood,
    :retweets,
    :state,
    :stolen_record,
    :tweet

  def initialize(bike)
    self.bike = bike
    self.stolen_record = bike.current_stolen_record
    if bike.image_url.present?
      self.bike_photo_url = bike.image_url(:large)
    end
    self.close_twitter_accounts = TwitterAccount.in_proximity(stolen_record)
    self.nearest_twitter_account = close_twitter_accounts.find { |i| i.not_national? } || close_twitter_accounts.first
    self.city = stolen_record&.city
    self.state = stolen_record&.state&.abbreviation
    self.neighborhood = stolen_record&.neighborhood
  end

  # To manually send a tweet (e.g. if authentication failed)
  # Integrations::TwitterTweeter.new(Bike.find(XXX)).create_tweet
  def create_tweet
    return if stolen_record.blank? || nearest_twitter_account.blank?

    posted_tweet =
      post_tweet_with_account(nearest_twitter_account,
        build_bike_status,
        lat: stolen_record.latitude,
        long: stolen_record.longitude,
        display_coordinates: "true")

    return if posted_tweet.blank?

    self.tweet = Tweet.new(
      twitter_id: posted_tweet.id,
      twitter_account_id: nearest_twitter_account&.id,
      stolen_record_id: stolen_record&.id,
      twitter_response: posted_tweet,
      kind: "stolen_tweet"
    )

    unless tweet.save
      nearest_twitter_account.set_error(tweet.errors.full_messages.to_sentence)
    end

    retweet(posted_tweet)
    tweet
  end

  def retweetable_accounts
    return [] if MAX_RETWEET_COUNT < 1
    close_twitter_accounts.reject { |t| t.id == nearest_twitter_account.id }[0..MAX_RETWEET_COUNT]
  end

  def retweet(posted_tweet)
    self.retweets = [tweet]

    retweetable_accounts.each do |twitter_account|
      retweet = tweet.retweet_to_account(twitter_account)
      retweets << retweet if retweet.present?
    end

    retweets
  end

  def stolen_slug
    if !bike.status_stolen? || bike.status_abandoned?
      "FOUND -"
    else
      "STOLEN -"
    end
  end

  def compute_max_char
    # TODO store these constants in the database and update them once a day with
    # a REST client.configuration call
    #
    # spaces between slugs
    # max_char = TWEET_LENGTH - https_length - at_screen_name.length - 3

    https_length = 23
    media_length = 23

    # spaces between slugs
    max = TWEET_LENGTH - https_length - stolen_slug.size - 3
    max -= bike_photo_url ? media_length : 0

    max
  end

  def tweet_string(stolen_slug, bike_slug, url)
    "#{stolen_slug} #{bike_slug} #{url}"
  end

  def tweet_string_with_options(stolen_slug, bike_slug, url)
    ts = tweet_string(stolen_slug, bike_slug, url)

    if close_twitter_accounts&.first&.append_block.present?
      block = nearest_twitter_account.append_block
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
      color = "Gray"
    elsif color.start_with?("Yellow")
      color = "Yellow"
    elsif color.start_with?("Sticker")
      color = "Stickers"
    end

    manufacturer = bike.mnfg_name
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

  private

  def bike_url(bike)
    "https://bikeindex.org/bikes/#{bike.id}"
  end

  def post_tweet_with_account(account, text, **opts)
    return if account.blank?
    tweet = nil

    if bike_photo_url.present?
      Tempfile.open("foto.jpg") do |foto|
        foto.binmode
        foto.write URI.parse(bike_photo_url).open.read # TODO: Refactor this.
        foto.rewind
        tweet = account.tweet(text, foto, opts)
      end
    else
      tweet = account.tweet(text, opts)
    end

    tweet
  end
end
