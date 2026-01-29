# == Schema Information
#
# Table name: social_accounts
# Database name: primary
#
#  id              :integer          not null, primary key
#  account_info    :jsonb
#  active          :boolean          default(FALSE), not null
#  address_string  :string
#  append_block    :string
#  city            :string
#  consumer_key    :string
#  consumer_secret :string
#  default         :boolean          default(FALSE), not null
#  language        :string
#  last_error      :string
#  last_error_at   :datetime
#  latitude        :float
#  longitude       :float
#  national        :boolean          default(FALSE), not null
#  neighborhood    :string
#  platform        :integer          default("twitter"), not null
#  screen_name     :string           not null
#  street          :string
#  user_secret     :string
#  user_token      :string           not null
#  zipcode         :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  country_id      :bigint
#  state_id        :bigint
#
# Indexes
#
#  index_social_accounts_on_country_id              (country_id)
#  index_social_accounts_on_latitude_and_longitude  (latitude,longitude)
#  index_social_accounts_on_platform                (platform)
#  index_social_accounts_on_screen_name             (screen_name)
#  index_social_accounts_on_state_id                (state_id)
#
class SocialAccount < ApplicationRecord
  include Geocodeable

  PLATFORM_ENUM = {twitter: 0, bluesky: 1}.freeze

  has_many :social_posts, dependent: :destroy

  validates :screen_name, :user_token, presence: true
  validates :consumer_key, :consumer_secret, :user_secret, presence: true, if: :twitter?

  validates :screen_name, uniqueness: {scope: :platform}

  before_save :reverse_geocode, if: :should_be_reverse_geocoded?
  before_save :fetch_account_info, if: :twitter?

  enum :platform, PLATFORM_ENUM

  scope :active, -> { where(active: true) }
  scope :national, -> { active.where(national: true) }
  scope :not_national, -> { active.where(national: false) }
  scope :errored, -> { where.not(last_error_at: nil) }

  reverse_geocoded_by :latitude, :longitude do |account, results|
    if (geo = results.first)
      account.city = geo.city
      account.neighborhood = geo.neighborhood
      country = Country.friendly_find(geo.country)
      account.country = country
      account.state = State.friendly_find(geo.state_code) if country&.united_states?
    end
  end

  def self.fuzzy_screen_name_find(name)
    return if name.blank?

    where("lower(screen_name) = ?", name.downcase.strip).first
  end

  def self.friendly_find(str)
    return nil if str.blank?
    return where(id: str).first if str.is_a?(Integer) || str.match(/\A\d+\z/).present?

    fuzzy_screen_name_find(str)
  end

  def self.default_account
    where(default: true).first || national.first
  end

  def self.default_account_for_country(country_name)
    country = Country.friendly_find(country_name)
    national.where(country: country).first || default_account
  end

  def self.find_or_create_from_twitter_oauth(info)
    attrs = attrs_from_user_info(info)
    social_account = find_or_initialize_by(screen_name: attrs.delete(:screen_name))
    social_account.update(attrs)
    social_account
  end

  def self.attrs_from_user_info(info)
    {
      screen_name: info["info"]["nickname"],
      address_string: info["info"]["location"],
      consumer_key: ENV["TWITTER_CONSUMER_KEY"],
      consumer_secret: ENV["TWITTER_CONSUMER_SECRET"],
      user_token: info["credentials"]["token"],
      user_secret: info["credentials"]["secret"]
    }
  end

  def self.get_post(post_id)
    default_account.get_post(post_id)
  end

  def self.in_proximity(obj = nil)
    return [] unless obj&.to_coordinates&.compact.present?

    [
      active.near(obj.to_coordinates, 50),
      default_account_for_country(obj&.country)
    ].flatten.compact.uniq
  end

  def account_url
    if bluesky?
      "https://bsky.app/profile/#{screen_name}"
    else
      "https://twitter.com/#{screen_name}"
    end
  end

  def fetch_account_info
    return account_url if account_info.present?

    self.account_info = platform_user
    self.created_at = Binxtils::TimeParser.parse(account_info["created_at"])
    account_info
  end

  def platform_user
    @platform_user ||= platform_client.user(screen_name).to_h
  end

  def account_info_name
    return if account_info.blank?

    account_info["name"]
  end

  def account_info_image
    return if account_info.blank?

    account_info["profile_image_url_https"]
  end

  def set_error(message)
    update(last_error: message, last_error_at: Time.current)
  end

  def clear_error
    update(last_error: nil, last_error_at: nil)
  end

  def errored?
    last_error_at.present?
  end

  def not_national?
    !national
  end

  def check_credentials
    clear_error
    platform_client.verify_credentials
  rescue Twitter::Error::Unauthorized, Twitter::Error::Forbidden => err
    set_error(err.message)
  end

  def post(text, photo = nil, **opts)
    nil unless text.present?

    # Commented out in #2618 - twitter is disabled
    #
    # if photo.present?
    #   platform_client.update_with_media(text, photo, opts)
    # else
    #   platform_client.update(text, opts)
    # end
  rescue Twitter::Error::Unauthorized, Twitter::Error::Forbidden => err
    set_error(err.message)
    nil
  end

  def repost(post_id)
    return unless post_id.present?

    platform_client.retweet(post_id).first
  rescue Twitter::Error::Unauthorized, Twitter::Error::Forbidden => err
    set_error(err.message)
    nil
  end

  def get_post(post_id)
    platform_client.status(post_id)
  end

  def should_be_reverse_geocoded?
    !skip_geocoding? &&
      latitude.present? &&
      (state.blank? || state_id_changed?)
  end

  private

  def platform_client
    @platform_client ||= Twitter::REST::Client.new { |config|
      config.consumer_key = consumer_key
      config.consumer_secret = consumer_secret
      config.access_token = user_token
      config.access_token_secret = user_secret
    }
  end
end
