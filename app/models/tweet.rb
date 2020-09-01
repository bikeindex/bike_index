class Tweet < ApplicationRecord
  KIND_ENUM = {stolen_tweet: 0, imported_tweet: 1, app_tweet: 2}.freeze
  VALID_ALIGNMENTS = %w[top-left top-right bottom-left bottom-right].freeze
  validates :twitter_id, presence: true, uniqueness: true
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

  enum kind: KIND_ENUM

  scope :retweet, -> { where.not(original_tweet: nil) }
  scope :excluding_retweets, -> { where(original_tweet: nil) }
  scope :not_stolen, -> { where.not(kind: "stolen_tweet") }

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.friendly_find(id)
    return nil if id.blank?
    id = id.to_s
    query = id.length > 15 ? {twitter_id: id} : {id: id}
    order(created_at: :desc).find_by(query)
  end

  def self.auto_link_text(text)
    text.gsub(/@([^\s])*/) {
      username = Regexp.last_match[0]
      "<a href=\"https://twitter.com/#{username.delete("@")}\" target=\"_blank\">#{username}</a>"
    }.gsub(/#([^\s])*/) do
      hashtag = Regexp.last_match[0]
      "<a href=\"https://twitter.com/hashtag/#{hashtag.delete("#")}\" target=\"_blank\">#{hashtag}</a>"
    end
  end

  def self.admin_search(str)
    return none unless str.present?
    text = str.strip
    # If passed a number, assume it is a bike ID and search for that bike_id
    if text.is_a?(Integer) || text.match(/\A\d*\z/).present?
      return includes(:stolen_record).where(stolen_records: {bike_id: text})
    end
    where("body_html ILIKE ?", "%#{text}%").or(where("body ILIKE ?", "%#{text}%"))
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
    self.alignment ||= VALID_ALIGNMENTS.first
    unless VALID_ALIGNMENTS.include?(alignment)
      errors[:base] << "#{alignment} is not one of valid alignments: #{VALID_ALIGNMENTS}"
    end
    self.kind ||= calculated_kind
    if imported_tweet?
      self.body_html ||= self.class.auto_link_text(trh[:text]) if trh.dig(:text).present?
    else
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
    trh.dig(:entities, :media).first&.dig(:media_url)
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
    twitter_account&.twitter_account_url || "https://twitter.com/#{tweetor}"
  end

  def tweet_link
    if twitter_account.present?
      [twitter_account.twitter_account_url, "status", twitter_id].join("/")
    else
      "https://twitter.com/#{tweetor}/status/#{twitter_id}"
    end
  end

  def details_hash
    @details_hash ||= begin
      {}.tap do |details|
        details[:notification_type] = "stolen_twitter_alerter"
        details[:bike_id] = bike&.id
        details[:tweet_id] = twitter_id
        details[:tweet_string] = body_html
        details[:tweet_account_screen_name] = tweetor
        details[:tweet_account_name] = twitter_account&.account_info_name
        details[:tweet_account_image] = twitter_account&.account_info_image
        details[:retweet_screen_names] = retweets.map(&:tweetor)

        if !twitter_account&.national? && twitter_account&.address.present?
          details[:location] = twitter_account.address.split(",").first.strip
        end
      end
    end
  end

  private

  def calculated_kind
    return "stolen_tweet" if stolen_record.present?
    return "imported_tweet" if twitter_id.present?
    "manual_tweet"
  end
end
