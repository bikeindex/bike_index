class Tweet < ActiveRecord::Base
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

  before_save :set_body_from_response
  before_validation :ensure_valid_alignment

  scope :excluding_retweets, -> { where(original_tweet: nil) }

  def self.friendly_find(id)
    return nil if id.blank?
    id = id.to_s
    query = id.length > 7 ? { twitter_id: id } : { id: id }
    order(created_at: :desc).find_by(query)
  end

  def self.auto_link_text(text)
    text.gsub /@([^\s])*/ do
      username = Regexp.last_match[0]
      "<a href=\"https://twitter.com/#{username.delete("@")}\" target=\"_blank\">#{username}</a>"
    end.gsub /#([^\s])*/ do
      hashtag = Regexp.last_match[0]
      "<a href=\"https://twitter.com/hashtag/#{hashtag.delete("#")}\" target=\"_blank\">#{hashtag}</a>"
    end
  end

  def retweet?
    original_tweet.present?
  end

  def to_param
    twitter_id
  end

  def ensure_valid_alignment
    valid_alignments = %w(top-left top-right bottom-left bottom-right)
    self.alignment ||= valid_alignments.first
    return true if valid_alignments.include?(alignment)
    self.errors[:base] << "#{alignment} is not one of valid alignments: #{valid_alignments}"
  end

  def set_body_from_response
    return true unless body_html.blank? && twitter_response && twitter_response["text"].present?
    self.body_html = self.class.auto_link_text(twitter_response["text"])
  end

  def trh
    twitter_response || {} # so we don't explode when there is no response
  end

  def tweeted_at
    Time.parse(trh["created_at"])
  end

  def tweetor
    return twitter_account.screen_name if twitter_account&.screen_name.present?
    trh["user"] && trh["user"]["screen_name"]
  end

  def tweetor_avatar
    trh["user"] && trh["user"]["profile_image_url_https"]
  end

  def tweetor_name
    trh["user"] && trh["user"]["name"]
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
        details[:bike_id] = stolen_record&.bike&.id
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
end
