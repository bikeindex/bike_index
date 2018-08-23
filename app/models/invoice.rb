# frozen_string_literal: true

class Invoice < ActiveRecord::Base
  belongs_to :organization
  belongs_to :subscription_first_invoice, class_name: "Invoice"

  before_save :set_calculated_attributes

  scope :first_invoice, -> { where(renews_subscription_id: nil) }
  scope :renewal_invoice, -> { where.not(renews_subscription_id: nil) }
  scope :active, -> { where(is_active: true).where.not(subscription_start_at: nil) }
  scope :current, -> { active.where("subscription_end_at > ?", Time.now) }
  scope :expired, -> { active.where("subscription_end_at < ?", Time.now) }

  def subscription_duration; 1.year end # Static, at least for now
  def first_invoice?; renews_subscription_id.present? end
  def renewal?; !initial? end
  def active?; is_active && subscription_start_at.present? end # prolly remove is_active later, once automated
  def current?; active? && subscription_end_at > Time.now end
  def expired?; active? && !current? end
  def discount; features_at_start_cents end

  def feature_cost
    first_invoice? ? paid_features.sum(:recurring) : paid_features.sum(:recurring)
  end

  def set_features_at_start_cents
    update_attributes(features_at_start_upfront_cents: paid_features.upfront.sum(:amount_cents),
                      features_at_start_recurring_cents: paid_features.recurring.sum(:amount_cents))
  end

  def set_calculated_attributes
    self.subscription_start_at ||= subscription_first_invoice&.subscription_end_at || Time.now
    self.subscription_end_at ||= subscription_start_at + subscription_duration
  end
end
