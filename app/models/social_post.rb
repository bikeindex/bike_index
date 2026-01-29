# == Schema Information
#
# Table name: social_posts
# Database name: primary
#
#  id                :integer          not null, primary key
#  alignment         :string
#  body              :text
#  body_html         :text
#  image             :string
#  kind              :integer
#  platform_response :json
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  original_post_id  :integer
#  platform_id       :string
#  social_account_id :integer
#  stolen_record_id  :integer
#
# Indexes
#
#  index_social_posts_on_original_post_id   (original_post_id)
#  index_social_posts_on_social_account_id  (social_account_id)
#  index_social_posts_on_stolen_record_id   (stolen_record_id)
#
class SocialPost < ApplicationRecord
  KIND_ENUM = {stolen_post: 0, imported_post: 1, app_post: 2}.freeze
  VALID_ALIGNMENTS = %w[top-left top-right bottom-left bottom-right].freeze
  validates :platform_id, uniqueness: true, allow_blank: true
  has_many :public_images, as: :imageable, dependent: :destroy

  belongs_to :social_account
  belongs_to :stolen_record

  belongs_to :original_post, class_name: "SocialPost"
  has_many :reposts,
    foreign_key: :original_post_id,
    class_name: "SocialPost",
    dependent: :destroy

  mount_uploader :image, ImageUploader

  before_validation :set_calculated_attributes

  enum :kind, KIND_ENUM

  scope :repost, -> { where.not(original_post: nil) }
  scope :not_repost, -> { where(original_post: nil) }
  scope :not_stolen, -> { where.not(kind: "stolen_post") }

  class << self
    def kinds
      KIND_ENUM.keys.map(&:to_s)
    end

    def friendly_find(id)
      return nil if id.blank?

      id = id.to_s
      query = (id.length > 15) ? {platform_id: id} : {id: id}
      order(created_at: :desc).find_by(query)
    end

    def auto_link_text(text)
      text.gsub(/@([^\s])*/) {
        username = Regexp.last_match[0]
        "<a href=\"https://twitter.com/#{username.delete("@")}\" target=\"_blank\">#{username}</a>"
      }.gsub(/#([^\s])*/) do
        hashtag = Regexp.last_match[0]
        "<a href=\"https://twitter.com/hashtag/#{hashtag.delete("#")}\" target=\"_blank\">#{hashtag}</a>"
      end
    end

    def admin_search(str)
      return none unless str.present?

      text = str.strip
      # If passed a number, assume it is a bike ID and search for that bike_id
      if text.is_a?(Integer) || text.match(/\A\d+\z/).present?
        if text.to_i > 2147483647 # max rails integer, assume it's a platform_id instead
          return where("platform_id ILIKE ?", "%#{text}%")
        else
          return includes(:stolen_record).where(stolen_records: {bike_id: text})
        end
      end
      where("body_html ILIKE ?", "%#{text}%").or(where("body ILIKE ?", "%#{text}%"))
    end

    # Required because of the rename from Tweet
    def uploader_abbr
      "Tw"
    end
  end

  # TODO: Add actual testing of this. It isn't tested right now, sorry :/
  def send_post
    return true unless app_post? && platform_response.blank?

    if image.present?
      Tempfile.open("foto.jpg") do |foto|
        foto.binmode
        foto.write open_image.read # TODO: Refactor this.
        foto.rewind
        posted = social_account.post(body, foto)
        update(platform_response: posted.as_json)
      end
    else
      posted = social_account.post(body)
      update(platform_response: posted.as_json)
    end
    posted
  end

  # TODO: Add actual testing of this. It isn't tested right now, sorry :/
  def repost_to_account(repost_account)
    return nil if repost_account.id.to_i == social_account_id.to_i

    posted_repost = repost_account.repost(platform_id)
    return nil if posted_repost.blank?

    repost = SocialPost.new(
      platform_id: posted_repost.id,
      social_account_id: repost_account.id,
      stolen_record_id: stolen_record_id,
      original_post_id: id
    )

    unless repost.save
      repost_account.set_error(repost.errors.full_messages.to_sentence)
    end
    repost
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

  def repost?
    original_post.present?
  end

  def to_param
    platform_id
  end

  def set_calculated_attributes
    self.kind ||= calculated_kind
    if imported_post?
      self.body_html ||= self.class.auto_link_text(prh[:text]) if prh.dig(:text).present?
      self.alignment ||= VALID_ALIGNMENTS.first
      unless VALID_ALIGNMENTS.include?(alignment)
        errors.add "#{alignment} is not one of valid alignments: #{VALID_ALIGNMENTS}"
      end
    else
      if kind == "app_post" && platform_id.blank?
        errors.add "You need to choose an account" unless social_account.present?
        errors.add "You need to include post text" unless body.present?
      end
      self.platform_id ||= prh[:id]
      self.body ||= posted_text
    end
  end

  def prh
    (platform_response || {}).with_indifferent_access
  end

  def posted_at
    Binxtils::TimeParser.parse(prh[:created_at])
  end

  def posted_image
    return nil unless prh.dig(:entities, :media).present?

    prh.dig(:entities, :media).first&.dig(:media_url_https)
  end

  def posted_text
    prh[:text]
  end

  def poster
    return social_account.screen_name if social_account&.screen_name.present?

    prh.dig(:user, :screen_name)
  end

  def poster_avatar
    prh.dig(:user, :profile_image_url_https)
  end

  def poster_name
    prh.dig(:user, :name)
  end

  def poster_link
    social_account&.account_url || "https://twitter.com/#{poster}"
  end

  def post_link
    if social_account.present?
      [social_account.account_url, "status", platform_id].join("/")
    else
      "https://twitter.com/#{poster}/status/#{platform_id}"
    end
  end

  def details_hash
    @details_hash ||= {}.tap do |details|
      details[:notification_type] = "stolen_twitter_alerter"
      details[:bike_id] = bike&.id
      details[:tweet_id] = platform_id
      details[:tweet_string] = body_html
      details[:tweet_account_screen_name] = poster
      details[:tweet_account_name] = social_account&.account_info_name
      details[:tweet_account_image] = social_account&.account_info_image
      details[:retweet_screen_names] = reposts.map(&:poster)

      if !social_account&.national? && social_account&.address_string.present?
        details[:location] = social_account.address_string.split(",").first.strip
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
    return "stolen_post" if stolen_record_id.present?
    return "imported_post" if platform_id.present?

    "app_post"
  end
end
