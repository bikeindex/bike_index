# frozen_string_literal: true

# == Schema Information
#
# Table name: shopify_integrations
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  access_token           :text             not null
#  deleted_at             :datetime
#  last_error             :string
#  last_error_at          :datetime
#  last_order_at          :datetime
#  scopes                 :string
#  shop_data              :jsonb
#  shop_domain            :string           not null
#  status                 :integer          default("pending"), not null
#  webhooks_registered_at :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  organization_id        :bigint           not null
#  user_id                :bigint           not null
#
# Indexes
#
#  index_shopify_integrations_on_organization_id  (organization_id)
#  index_shopify_integrations_on_shop_domain      (shop_domain) UNIQUE WHERE (deleted_at IS NULL)
#
class ShopifyIntegration < ApplicationRecord
  STATUS_ENUM = {pending: 0, active: 1, error: 2}.freeze

  acts_as_paranoid

  enum :status, STATUS_ENUM

  belongs_to :organization
  belongs_to :user

  validates :shop_domain, presence: true
  validates :access_token, presence: true, unless: :deleted_at?
  validates :shop_domain, uniqueness: {conditions: -> { where(deleted_at: nil) }}

  before_validation :set_calculated_attributes
  before_destroy :mark_disconnected

  scope :webhooks_unregistered, -> { where(webhooks_registered_at: nil) }

  class << self
    # Shopify sends the shop as "example.myshopify.com" everywhere except the install
    # form, where a merchant types whatever they think their store is called
    def normalize_shop_domain(str)
      str = str.to_s.strip.downcase.delete_prefix("https://").delete_prefix("http://")
      # The URL in a merchant's address bar is the admin one, which names the store in its
      # path - taking its host would connect them to a store called "admin"
      return store_from_admin_url(str) if str.start_with?("admin.shopify.com/store/")

      domain = str.split("/").first.to_s.delete_suffix(".")
      return nil if domain.blank?

      domain.end_with?(".myshopify.com") ? domain : "#{domain.split(".").first}.myshopify.com"
    end

    def valid_shop_domain?(str)
      normalize_shop_domain(str)&.match?(/\A[a-z0-9][a-z0-9-]*\.myshopify\.com\z/) || false
    end

    def friendly_find(str)
      find_by(shop_domain: normalize_shop_domain(str))
    end

    private

    def store_from_admin_url(str)
      store = str.split("/")[2]
      store.present? ? "#{store}.myshopify.com" : nil
    end
  end

  def shop_name
    shop_data&.dig("name") || shop_domain
  end

  def shop_url
    "https://#{shop_domain}"
  end

  def admin_url
    "https://admin.shopify.com/store/#{shop_domain.delete_suffix(".myshopify.com")}"
  end

  # Counted rather than stored: orders/updated redelivers a sale every time the shop edits
  # it, and the duplicate check means a redelivery returns the bike it already registered
  def registrations_count
    organization.created_bikes.shopify_pos.count
  end

  def record_error(message)
    update(status: :error, last_error: message.to_s.truncate(255), last_error_at: Time.current)
  end

  def record_order
    update(status: :active, last_order_at: Time.current, last_error: nil, last_error_at: nil)
  end

  private

  def set_calculated_attributes
    self.shop_domain = self.class.normalize_shop_domain(shop_domain)
  end

  # Shopify invalidates the token on uninstall anyway - dropping it means a re-install
  # can't resurrect a stale one
  def mark_disconnected
    update_columns(access_token: "", webhooks_registered_at: nil)
  end
end
