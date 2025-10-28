require "tempfile"
require "open-uri"
require "net/http"
require "json"

class Integrations::BlueskyPoster
  POST_LENGTH = 300
  BLUESKY_API_URL = "https://bsky.social/xrpc"

  attr_accessor \
    :bike,
    :bike_photo_url,
    :city,
    :max_char,
    :national_twitter_account,
    :neighborhood,
    :state,
    :stolen_record,
    :tweet

  def initialize(bike)
    self.bike = bike
    self.stolen_record = bike.current_stolen_record
    if bike.image_url.present?
      self.bike_photo_url = bike.image_url(:large)
    end
    self.national_twitter_account = TwitterAccount.national.first
    self.city = stolen_record&.city
    self.state = stolen_record&.state&.abbreviation
    self.neighborhood = stolen_record&.neighborhood
  end

  # To manually send a post (e.g. if authentication failed)
  # Integrations::BlueskyPoster.new(Bike.find(XXX)).create_post
  def create_post
    return if stolen_record.blank? || national_twitter_account.blank?

    posted_response = post_to_bluesky(
      build_bike_status,
      lat: stolen_record.latitude,
      long: stolen_record.longitude
    )

    return if posted_response.blank?

    self.tweet = Tweet.new(
      twitter_id: posted_response["uri"],
      twitter_account_id: national_twitter_account&.id,
      stolen_record_id: stolen_record&.id,
      twitter_response: posted_response,
      kind: "stolen_tweet"
    )

    unless tweet.save
      national_twitter_account.set_error(tweet.errors.full_messages.to_sentence)
    end

    tweet
  end

  def stolen_slug
    if !bike.status_stolen? || bike.status_abandoned?
      "FOUND -"
    else
      "STOLEN -"
    end
  end

  def compute_max_char
    # Bluesky has a 300 character limit
    # Account for URL length (roughly 23 chars after shortening)
    https_length = 23

    # spaces between slugs (stolen_slug already includes trailing space/dash)
    max = POST_LENGTH - https_length - stolen_slug.size - 2

    max
  end

  def post_string(stolen_slug, bike_slug, url)
    "#{stolen_slug} #{bike_slug} #{url}"
  end

  def post_string_with_options(stolen_slug, bike_slug, url)
    ps = post_string(stolen_slug, bike_slug, url)

    if national_twitter_account&.append_block.present?
      block = national_twitter_account.append_block
      ps << " #{block}" if (ps.length + block.length) < max_char
    end

    ps
  end

  # Perform the conditional text processing to create a post string
  # that fits Bluesky's limits
  def build_bike_status
    self.max_char = compute_max_char

    # For national account, always use city and state
    location = [city, state].compact.join(", ")
    location = "in #{location}" if location.present?

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
    post_string_with_options(stolen_slug, bike_slug, bike_url(bike))
  end

  private

  def bike_url(bike)
    "https://bikeindex.org/bikes/#{bike.id}"
  end

  def post_to_bluesky(text, lat: nil, long: nil)
    return if national_twitter_account.blank? || text.blank?

    session = create_bluesky_session
    return if session.blank?

    post_data = {
      repo: session["did"],
      collection: "app.bsky.feed.post",
      record: {
        text:,
        createdAt: Time.current.iso8601,
        "$type": "app.bsky.feed.post"
      }
    }

    # Add location if available
    if lat.present? && long.present?
      post_data[:record][:location] = {
        latitude: lat,
        longitude: long
      }
    end

    # Handle image upload if present
    if bike_photo_url.present?
      blob = upload_image_to_bluesky(session)
      if blob.present?
        post_data[:record][:embed] = {
          "$type": "app.bsky.embed.images",
          images: [{
            alt: "Stolen bike photo",
            image: blob
          }]
        }
      end
    end

    uri = URI("#{BLUESKY_API_URL}/com.atproto.repo.createRecord")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path, {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{session["accessJwt"]}"
    })
    request.body = post_data.to_json

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      national_twitter_account.set_error("Bluesky API error: #{response.code} #{response.body}")
      nil
    end
  rescue => e
    national_twitter_account.set_error("Bluesky error: #{e.message}")
    nil
  end

  def create_bluesky_session
    # Get credentials from TwitterAccount (reusing existing fields)
    # consumer_key stores Bluesky handle
    # consumer_secret stores Bluesky app password
    handle = national_twitter_account.consumer_key
    password = national_twitter_account.consumer_secret

    uri = URI("#{BLUESKY_API_URL}/com.atproto.server.createSession")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path, {"Content-Type" => "application/json"})
    request.body = {identifier: handle, password:}.to_json

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      national_twitter_account.set_error("Bluesky auth failed: #{response.code}")
      nil
    end
  rescue => e
    national_twitter_account.set_error("Bluesky auth error: #{e.message}")
    nil
  end

  def upload_image_to_bluesky(session)
    Tempfile.open("foto.jpg") do |foto|
      foto.binmode
      foto.write URI.parse(bike_photo_url).open.read
      foto.rewind

      uri = URI("#{BLUESKY_API_URL}/com.atproto.repo.uploadBlob")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path, {
        "Content-Type" => "image/jpeg",
        "Authorization" => "Bearer #{session["accessJwt"]}"
      })
      request.body = foto.read

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)["blob"]
      else
        nil
      end
    end
  rescue => e
    nil
  end
end
