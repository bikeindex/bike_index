class Tweet < ActiveRecord::Base
  validates_presence_of :twitter_id
  has_many :public_images, as: :imageable, dependent: :destroy
  mount_uploader :image, ImageUploader
  process_in_background :image, CarrierWaveProcessWorker
  before_save :set_body_from_response
  before_validation :ensure_valid_alignment

  def self.friendly_find(id)
    return nil unless id.present?
    id = id.to_s
    if id.length > 7
      Tweet.where(twitter_id: id).first
    else
      Tweet.where(id: id).first
    end
  end

  def self.auto_link_text(text)
    text.gsub /@([^\s])*/ do
      username = Regexp.last_match[0]
      "<a href=\"https://twitter.com/#{username.delete('@')}\" target=\"_blank\">#{username}</a>"
    end.gsub /#([^\s])*/ do
      hashtag = Regexp.last_match[0]
      "<a href=\"https://twitter.com/hashtag/#{hashtag.delete('#')}\" target=\"_blank\">#{hashtag}</a>"
    end
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
    return true unless body_html.blank? && twitter_response && twitter_response['text'].present?
    self.body_html = self.class.auto_link_text(twitter_response['text'])
  end

  def trh
    twitter_response || {} # so we don't explode when there is no response
  end

  def tweeted_at
    Time.parse(trh['created_at'])
  end

  def tweetor
    trh['user'] && trh['user']['screen_name']
  end

  def tweetor_avatar
    trh['user'] && trh['user']['profile_image_url_https']
  end

  def tweetor_name
    trh['user'] && trh['user']['name']
  end

  def tweetor_link
    "https://twitter.com/#{tweetor}"
  end

  def tweet_link
    "https://twitter.com/#{tweetor}/status/#{twitter_id}"
  end
end
