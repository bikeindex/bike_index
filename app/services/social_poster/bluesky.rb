require "tempfile"
require "open-uri"

class SocialPoster::Bluesky
  POST_LENGTH = 300
  BLUESKY_API_URL = "https://bsky.social/xrpc".freeze

  attr_accessor \
    :bike,
    :bike_photo_url,
    :city,
    :max_char,
    :social_account,
    :state,
    :stolen_record,
    :post

  def initialize(bike)
    self.bike = bike
    self.stolen_record = bike.current_stolen_record
    if bike.image_url.present?
      self.bike_photo_url = bike.image_url(:large)
    end
    self.social_account = SocialAccount.bluesky.national.first
    self.city = stolen_record&.city
    self.state = stolen_record&.state&.abbreviation
  end

  # To manually send a post
  # SocialPoster::Bluesky.new(Bike.find(XXX)).create_post
  def create_post
    return if stolen_record.blank? || social_account.blank?

    posted = post_to_bluesky(build_post_text)

    return if posted.blank?

    self.post = SocialPost.new(
      platform_id: posted[:uri],
      social_account_id: social_account.id,
      stolen_record_id: stolen_record.id,
      platform_response: posted,
      kind: "stolen_post"
    )

    unless post.save
      social_account.set_error(post.errors.full_messages.to_sentence)
    end

    post
  end

  def stolen_slug
    if !bike.status_stolen? || bike.status_abandoned?
      "FOUND -"
    else
      "STOLEN -"
    end
  end

  def compute_max_char
    url_length = bike_url(bike).length
    # Bluesky counts actual characters, not shortened URLs
    POST_LENGTH - url_length - stolen_slug.size - 3
  end

  def build_post_text
    self.max_char = compute_max_char

    location = ""
    if city.present? && state.present?
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
    "#{stolen_slug} #{bike_slug} #{bike_url(bike)}"
  end

  private

  def bike_url(bike)
    "https://bikeindex.org/bikes/#{bike.id}"
  end

  def post_to_bluesky(text)
    return if social_account.blank?

    session = create_session
    return if session.blank?

    record = build_post_record(text, session)

    if bike_photo_url.present?
      blob = upload_image(session)
      if blob.present?
        record[:embed] = {
          "$type" => "app.bsky.embed.images",
          :images => [{alt: "Photo of stolen bike", image: blob}]
        }
      end
    end

    response = create_record(session, record)
    social_account.clear_error if response.present?
    response
  rescue Faraday::Error => e
    social_account.set_error(e.message)
    nil
  end

  def create_session
    response = connection.post("com.atproto.server.createSession") do |req|
      req.body = {
        identifier: social_account.screen_name,
        password: social_account.user_token
      }.to_json
    end

    return nil unless response.success?

    JSON.parse(response.body).with_indifferent_access
  end

  def build_post_record(text, session)
    url = bike_url(bike)
    url_start = text.index(url)

    facets = []
    if url_start
      facets << {
        index: {
          byteStart: url_start,
          byteEnd: url_start + url.bytesize
        },
        features: [{
          "$type" => "app.bsky.richtext.facet#link",
          :uri => url
        }]
      }
    end

    {
      "$type" => "app.bsky.feed.post",
      :text => text,
      :createdAt => Time.current.iso8601,
      :facets => facets
    }
  end

  def create_record(session, record)
    response = connection.post("com.atproto.repo.createRecord") do |req|
      req.headers["Authorization"] = "Bearer #{session[:accessJwt]}"
      req.body = {
        repo: session[:did],
        collection: "app.bsky.feed.post",
        record:
      }.to_json
    end

    return nil unless response.success?

    JSON.parse(response.body).with_indifferent_access
  end

  def upload_image(session)
    Tempfile.open(["foto", ".jpg"]) do |foto|
      foto.binmode
      foto.write URI.parse(bike_photo_url).open.read
      foto.rewind

      response = connection.post("com.atproto.repo.uploadBlob") do |req|
        req.headers["Authorization"] = "Bearer #{session[:accessJwt]}"
        req.headers["Content-Type"] = "image/jpeg"
        req.body = foto.read
      end

      return nil unless response.success?

      JSON.parse(response.body).dig("blob")
    end
  end

  def connection
    @connection ||= Faraday.new(url: BLUESKY_API_URL) do |f|
      f.request :json
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end
  end
end
