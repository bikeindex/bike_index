# frozen_string_literal: true

# == Schema Information
#
# Table name: invoices
#
#  id                          :integer          not null, primary key
#  amount_due_cents            :integer
#  amount_paid_cents           :integer
#  child_enabled_feature_slugs :jsonb
#  currency_enum               :integer
#  force_active                :boolean          default(FALSE), not null
#  is_active                   :boolean          default(FALSE), not null
#  is_endless                  :boolean          default(FALSE)
#  notes                       :text
#  subscription_end_at         :datetime
#  subscription_start_at       :datetime
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  first_invoice_id            :integer
#  organization_id             :integer
#
# Indexes
#
#  index_invoices_on_first_invoice_id  (first_invoice_id)
#  index_invoices_on_organization_id   (organization_id)
#

# daily_maintenance_tasks updates all invoices that have expiring subscriptions every day
class Invoice < ApplicationRecord
  include Currencyable
  include Amountable # included for formatting stuff

  belongs_to :organization
  belongs_to :first_invoice, class_name: "Invoice" # Use subscription_first_invoice_id + subscription_first_invoice, NOT THIS

  has_many :invoice_organization_features, dependent: :destroy
  has_many :organization_features, through: :invoice_organization_features
  has_many :payments

  validates :organization, presence: true

  before_save :set_calculated_attributes
  after_commit :update_organization

  scope :first_invoice, -> { where(first_invoice_id: nil) }
  scope :renewal_invoice, -> { where.not(first_invoice_id: nil) }
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :paid, -> { where.not(amount_due_cents: 0) }
  scope :free, -> { where(amount_due_cents: 0) }
  scope :current, -> { active.where("subscription_end_at > ? AND subscription_start_at < ?", Time.current, Time.current) }
  scope :expired, -> { where.not(subscription_start_at: nil).where("subscription_end_at < ?", Time.current) }
  scope :future, -> { where("subscription_start_at > ?", Time.current) }
  scope :endless, -> { where(is_endless: true) }
  scope :not_endless, -> { where.not(is_endless: true) }
  scope :should_expire, -> { not_endless.where(is_active: true).where("subscription_end_at < ?", Time.current) }
  scope :should_activate, -> { where(is_active: false).where("subscription_start_at < ? AND subscription_end_at > ?", Time.current, Time.current) }

  attr_accessor :timezone

  def self.friendly_find(str)
    str = str[/\d+/] if str.is_a?(String)
    where(id: str).first
  end

  def self.feature_slugs
    includes(:organization_features).pluck(:feature_slugs).flatten.uniq
  end

  def law_enforcement_functionality_invoice?
    organization_features.pluck(:name).any? { |n| n.match?(/law enforcement/i) }
  end

  # Static, at least for now
  def subscription_duration
    1.year
  end

  def renewal_invoice?
    first_invoice_id.present?
  end

  # Alias - don't directly access the db attribute, because it might change
  def active?
    is_active
  end

  def endless?
    is_endless
  end

  def not_endless?
    !endless?
  end

  def expired?
    not_endless? && subscription_end_at && subscription_end_at < Time.current
  end

  def future?
    subscription_start_at && subscription_start_at > Time.current
  end

  def current?
    active? && !expired? && !future?
  end

  def was_active?
    !future? && (expired? && force_active || subscription_start_at.present? && paid_in_full?)
  end

  # Use db attribute here, because that's what matters
  def should_expire?
    is_active && expired?
  end

  def discount_cents
    feature_cost_cents - (amount_due_cents || 0)
  end

  def paid_in_full?
    amount_paid_cents.present? && amount_due_cents.present? && amount_paid_cents >= amount_due_cents
  end

  def costs_money?
    amount_due_cents > 0
  end

  def no_cost?
    !costs_money?
  end

  def paid_money_in_full?
    paid_in_full? && costs_money?
  end

  def subscription_first_invoice_id
    first_invoice_id || id
  end

  def subscription_first_invoice
    first_invoice || self
  end

  def subscription_invoices
    self.class.where(first_invoice_id: subscription_first_invoice_id).where.not(id: id)
  end

  def display_name
    "Invoice ##{id}"
  end

  def organization_feature_ids
    invoice_organization_features.pluck(:organization_feature_id)
  end

  # There can be multiple features of the same id. View the spec for additional info
  def organization_feature_ids=(val)
    # This isn't super efficient, but whateves
    val = val.to_s.split(",") unless val.is_a?(Array)
    new_features = val.map { |v| OrganizationFeature.where(id: v).first }.compact
    new_feature_ids = new_features.map(&:id)
    existing_feature_ids = invoice_organization_features.pluck(:organization_feature_id)
    (existing_feature_ids - new_feature_ids).uniq.each do |absent_id| # ids absent from new features
      invoice_organization_features.where(organization_feature_id: absent_id).delete_all
    end
    new_feature_ids.uniq.each do |feature_id|
      new_matching_ids = new_feature_ids.select { |i| i == feature_id }
      existing_matching_ids = existing_feature_ids.select { |i| i == feature_id }
      if new_matching_ids.count > existing_matching_ids.count
        (new_matching_ids.count - existing_matching_ids.count).times do
          invoice_organization_features.create(organization_feature_id: feature_id)
        end
      elsif new_matching_ids.count < existing_matching_ids.count
        (existing_matching_ids.count - new_matching_ids.count).times do
          invoice_organization_features.where(organization_feature_id: feature_id).first.delete
        end
      end
    end
  end

  def child_enabled_feature_slugs_string
    (child_enabled_feature_slugs || []).join(", ")
  end

  def child_enabled_feature_slugs_string=(val)
    return if val.blank?
    unless val.is_a?(Array)
      val = val.strip.split(",").map(&:strip)
    end
    valid_slugs = (val & feature_slugs)
    self.child_enabled_feature_slugs = valid_slugs
  end

  # So that we can read and write
  def start_at
    subscription_start_at
  end

  def end_at
    subscription_end_at
  end

  def start_at=(val)
    self.subscription_start_at = TimeParser.parse(val, timezone)
  end

  def end_at=(val)
    self.subscription_end_at = TimeParser.parse(val, timezone)
  end

  def amount_due
    amnt = (amount_due_cents.to_i / 100.00)
    (amnt % 1 != 0) ? amnt : amnt.round
  end

  def amount_due=(val)
    self.amount_due_cents = val.to_f * 100
  end

  def amount_due_formatted
    MoneyFormatter.money_format(amount_due_cents, currency_name)
  end

  def amount_paid_formatted
    MoneyFormatter.money_format(amount_paid_cents, currency_name)
  end

  def discount_formatted
    MoneyFormatter.money_format(-(discount_cents || 0), currency_name)
  end

  def previous_invoice
    return nil unless renewal_invoice?
    subscription_invoices.where("id < ?", id).reorder(:id).last || subscription_first_invoice
  end

  def following_invoice
    subscription_invoices.where("id > ?", id).reorder(:id).first
  end

  def feature_cost_cents
    organization_features.sum(:amount_cents)
  end

  def feature_slugs
    organization_features.pluck(:feature_slugs).flatten.uniq
  end

  def create_following_invoice
    return nil unless active? || was_active? || future?
    return following_invoice if following_invoice.present?
    new_invoice = organization.invoices.create(start_at: subscription_end_at,
      first_invoice_id: subscription_first_invoice_id)
    new_invoice.organization_feature_ids = organization_features.recurring.pluck(:id)
    new_invoice.reload
    new_invoice.update(child_enabled_feature_slugs: child_enabled_feature_slugs)
    new_invoice
  end

  def set_calculated_attributes
    self.amount_paid_cents = payments.sum(:amount_cents)
    if subscription_start_at.present?
      self.subscription_end_at ||= subscription_start_at + subscription_duration
    end
    self.is_active = !expired? && !future? && (force_active || paid_in_full?)
    self.child_enabled_feature_slugs ||= []
  end

  def update_organization
    UpdateOrganizationAssociationsJob.perform_async(organization_id)
  end
end
