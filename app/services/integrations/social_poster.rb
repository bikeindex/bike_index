require "twitter"
require "tempfile"
require "open-uri"

class Integrations::SocialPoster
  POST_LENGTH = 280
  MAX_REPOST_COUNT = (ENV["MAX_RETWEET_COUNT"] || 3).to_i

  attr_accessor \
    :bike,
    :bike_photo_url,
    :city,
    :close_social_accounts,
    :max_char,
    :nearest_social_account,
    :neighborhood,
    :reposts,
    :state,
    :stolen_record,
    :post

  def initialize(bike)
    self.bike = bike
    self.stolen_record = bike.current_stolen_record
    if bike.image_url.present?
      self.bike_photo_url = bike.image_url(:large)
    end
    self.close_social_accounts = SocialAccount.in_proximity(stolen_record)
    self.nearest_social_account = close_social_accounts.find { |i| i.not_national? } || close_social_accounts.first
    self.city = stolen_record&.city
    self.state = stolen_record&.state&.abbreviation
    self.neighborhood = stolen_record&.neighborhood
  end

  # To manually send a post (e.g. if authentication failed)
  # Integrations::SocialPoster.new(Bike.find(XXX)).create_post
  def create_post
    return if stolen_record.blank? || nearest_social_account.blank?

    posted =
      post_with_account(nearest_social_account,
        build_bike_status,
        lat: stolen_record.latitude,
        long: stolen_record.longitude,
        display_coordinates: "true")

    return if posted.blank?

    self.post = SocialPost.new(
      platform_id: posted.id,
      social_account_id: nearest_social_account&.id,
      stolen_record_id: stolen_record&.id,
      platform_response: posted,
      kind: "stolen_post"
    )

    unless post.save
      nearest_social_account.set_error(post.errors.full_messages.to_sentence)
    end

    repost(posted)
    post
  end

  def repostable_accounts
    return [] if MAX_REPOST_COUNT < 1

    close_social_accounts.reject { |t| t.id == nearest_social_account.id }[0..MAX_REPOST_COUNT]
  end

  def repost(posted)
    self.reposts = [post]

    repostable_accounts.each do |social_account|
      reposted = post.repost_to_account(social_account)
      reposts << reposted if reposted.present?
    end

    reposts
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
    # max_char = POST_LENGTH - https_length - at_screen_name.length - 3

    https_length = 23
    media_length = 23

    # spaces between slugs
    max = POST_LENGTH - https_length - stolen_slug.size - 3
    max -= bike_photo_url ? media_length : 0

    max
  end

  def post_string(stolen_slug, bike_slug, url)
    "#{stolen_slug} #{bike_slug} #{url}"
  end

  def post_string_with_options(stolen_slug, bike_slug, url)
    ts = post_string(stolen_slug, bike_slug, url)

    if close_social_accounts&.first&.append_block.present?
      block = nearest_social_account.append_block
      ts << " #{block}" if (ts.length + block.length) < max_char
    end

    ts
  end

  # Perform the conditional text processing to create a reply string
  # that fits twitter's limits
  #
  # param bike [Hash] bike hash as delivered by BikeIndex that we're going to post about
  def build_bike_status
    self.max_char = compute_max_char

    location = ""
    if !close_social_accounts&.first&.default? && neighborhood.present?
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
    post_string_with_options(stolen_slug, bike_slug, bike_url(bike))
  end

  private

  def bike_url(bike)
    "https://bikeindex.org/bikes/#{bike.id}"
  end

  def post_with_account(account, text, **opts)
    return if account.blank?

    posted = nil

    if bike_photo_url.present?
      Tempfile.open("foto.jpg") do |foto|
        foto.binmode
        foto.write URI.parse(bike_photo_url).open.read # TODO: Refactor this.
        foto.rewind
        posted = account.post(text, foto, opts)
      end
    else
      posted = account.post(text, opts)
    end

    posted
  end
end
