# == Schema Information
#
# Table name: tweets
# Database name: primary
#
#  id                 :integer          not null, primary key
#  alignment          :string
#  body               :text
#  body_html          :text
#  image              :string
#  kind               :integer
#  platform           :integer          default("twitter"), not null
#  twitter_response   :json
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  original_tweet_id  :integer
#  stolen_record_id   :integer
#  twitter_account_id :integer
#  twitter_id         :string
#
# Indexes
#
#  index_tweets_on_original_tweet_id   (original_tweet_id)
#  index_tweets_on_platform            (platform)
#  index_tweets_on_stolen_record_id    (stolen_record_id)
#  index_tweets_on_twitter_account_id  (twitter_account_id)
#
class Tweet < ApplicationRecord
  KIND_ENUM = {stolen_tweet: 0, imported_tweet: 1, app_tweet: 2}.freeze
  PLATFORM_ENUM = {twitter: 0, bluesky: 1}.freeze
  VALID_ALIGNMENTS = %w[top-left top-right bottom-left bottom-right].freeze
  validates :twitter_id, uniqueness: true, allow_blank: true
  has_many :public_images, as: :imageable, dependent: :destroy

  belongs_to :twitter_account
  belongs_to :stolen_record

  belongs_to :original_tweet, class_name: "Tweet"
  has_many :retweets,
    foreign_key: :original_tweet_id,
    class_name: "Tweet",
    dependent: :destroy

  mount_uploader :image, ImageUploader

  before_validation :set_calculated_attributes

  enum :kind, KIND_ENUM
  enum :platform, PLATFORM_ENUM

  scope :retweet, -> { where.not(original_tweet: nil) }
  scope :not_retweet, -> { where(original_tweet: nil) }
  scope :not_stolen, -> { where.not(kind: "stolen_tweet") }

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.friendly_find(id)
    return nil if id.blank?

    id = id.to_s
    query = (id.length > 15) ? {twitter_id: id} : {id: id}
    order(created_at: :desc).find_by(query)
  end

  def self.auto_link_text(text, platform = :twitter)
    if platform == :bluesky
      text.gsub(/@([^\s])*/) {
        username = Regexp.last_match[0]
        "<a href=\"https://bsky.app/profile/#{username.delete("@")}\" target=\"_blank\">#{username}</a>"
      }.gsub(/#([^\s])*/) do
        hashtag = Regexp.last_match[0]
        "<a href=\"https://bsky.app/search?q=#{hashtag.delete("#")}\" target=\"_blank\">#{hashtag}</a>"
      end
    else
      text.gsub(/@([^\s])*/) {
        username = Regexp.last_match[0]
        "<a href=\"https://twitter.com/#{username.delete("@")}\" target=\"_blank\">#{username}</a>"
      }.gsub(/#([^\s])*/) do
        hashtag = Regexp.last_match[0]
        "<a href=\"https://twitter.com/hashtag/#{hashtag.delete("#")}\" target=\"_blank\">#{hashtag}</a>"
      end
    end
  end

  def self.admin_search(str)
    return none unless str.present?

    text = str.strip
    # If passed a number, assume it is a bike ID and search for that bike_id
    if text.is_a?(Integer) || text.match(/\A\d+\z/).present?
      if text.to_i > 2147483647 # max rails integer, assume it's a twitter_id instead
        return where("twitter_id ILIKE ?", "%#{text}%")
      else
        return includes(:stolen_record).where(stolen_records: {bike_id: text})
      end
    end
    where("body_html ILIKE ?", "%#{text}%").or(where("body ILIKE ?", "%#{text}%"))
  end

  # TODO: Add actual testing of this. It isn't tested right now, sorry :/
  def send_tweet
    return true unless app_tweet? && twitter_response.blank?

    if image.present?
      Tempfile.open("foto.jpg") do |foto|
        foto.binmode
        foto.write open_image.read # TODO: Refactor this.
        foto.rewind
        tweeted = twitter_account.tweet(body, foto)
        update(twitter_response: tweeted.as_json)
      end
    else
      tweeted = twitter_account.tweet(body)
      update(twitter_response: tweeted.as_json)
    end
    tweeted
  end

  # TODO: Add actual testing of this. It isn't tested right now, sorry :/
  def retweet_to_account(retweet_account)
    return nil if retweet_account.id.to_i == twitter_account_id.to_i

    posted_retweet = retweet_account.retweet(twitter_id)
    return nil if posted_retweet.blank?

    retweet = Tweet.new(
      twitter_id: posted_retweet.id,
      twitter_account_id: retweet_account.id,
      stolen_record_id: stolen_record_id,
      original_tweet_id: id
    )

    unless retweet.save
      retweet_account.set_error(retweet.errors.full_messages.to_sentence)
    end
    retweet
  end

  # Because of recoveries
  def stolen_record
    return nil unless stolen_record_id.present?

    # Using super because maybe it will benefit from includes?
    super || StolenRecord.current_and_not.find(stolen_record_id)
  end

  def bike
    stolen_record&.bike
  end

  def retweet?
    original_tweet.present?
  end

  def to_param
    twitter_id
  end

  def set_calculated_attributes
    self.kind ||= calculated_kind
    # Set platform from twitter_account if not explicitly set
    if twitter_account.present? && (platform.nil? || platform == "twitter")
      self.platform = twitter_account.platform
    end
    self.platform ||= :twitter
    if imported_tweet?
      self.body_html ||= self.class.auto_link_text(trh[:text], platform) if trh.dig(:text).present?
      self.alignment ||= VALID_ALIGNMENTS.first
      unless VALID_ALIGNMENTS.include?(alignment)
        errors.add "#{alignment} is not one of valid alignments: #{VALID_ALIGNMENTS}"
      end
    else
      if kind == "app_tweet" && twitter_id.blank?
        errors.add "You need to choose an account" unless twitter_account.present?
        errors.add "You need to include tweet text" unless body.present?
      end
      self.twitter_id ||= trh[:id]
      self.body ||= tweeted_text
    end
  end

  def trh
    (twitter_response || {}).with_indifferent_access
  end

  def tweeted_at
    TimeParser.parse(trh[:created_at])
  end

  def tweeted_image
    return nil unless trh.dig(:entities, :media).present?

    trh.dig(:entities, :media).first&.dig(:media_url_https)
  end

  def tweeted_text
    trh[:text]
  end

  def tweetor
    return twitter_account.screen_name if twitter_account&.screen_name.present?

    trh.dig(:user, :screen_name)
  end

  def tweetor_avatar
    trh.dig(:user, :profile_image_url_https)
  end

  def tweetor_name
    trh.dig(:user, :name)
  end

  def tweetor_link
    twitter_account&.platform_account_url || default_platform_url
  end

  def tweet_link
    if twitter_account.present?
      if bluesky?
        # Bluesky post URLs use the format: https://bsky.app/profile/{handle}/post/{post-id}
        # Extract the post ID from the URI (format: at://did:plc:.../app.bsky.feed.post/...)
        post_id = if twitter_id.start_with?("at://")
          twitter_id.split("/").last
        else
          twitter_id
        end
        "#{twitter_account.platform_account_url}/post/#{post_id}"
      else
        [twitter_account.platform_account_url, "status", twitter_id].join("/")
      end
    else
      "#{default_platform_url}/status/#{twitter_id}"
    end
  end

  def default_platform_url
    if bluesky?
      "https://bsky.app/profile/#{tweetor}"
    else
      "https://twitter.com/#{tweetor}"
    end
  end

  def details_hash
    @details_hash ||= {}.tap do |details|
      details[:notification_type] = "stolen_twitter_alerter"
      details[:bike_id] = bike&.id
      details[:tweet_id] = twitter_id
      details[:tweet_string] = body_html
      details[:tweet_account_screen_name] = tweetor
      details[:tweet_account_name] = twitter_account&.account_info_name
      details[:tweet_account_image] = twitter_account&.account_info_image
      details[:retweet_screen_names] = retweets.map(&:tweetor)

      if !twitter_account&.national? && twitter_account&.address_string.present?
        details[:location] = twitter_account.address_string.split(",").first.strip
      end
    end
  end

  # Because the way we load the image is different if it's remote or local
  # This is hacky, but whatever. Copied from bulk_import
  def open_image
    local_image = image&._storage&.to_s == "CarrierWave::Storage::File"
    local_image ? File.open(image.path, "r") : URI.parse(image.url).open
  end

  private

  def calculated_kind
    return "stolen_tweet" if stolen_record_id.present?
    return "imported_tweet" if twitter_id.present?

    "app_tweet"
  end
end
