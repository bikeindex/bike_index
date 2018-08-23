# frozen_string_literal: true

class Invoice < ActiveRecord::Base
  belongs_to :organization
  belongs_to :first_invoice, class_name: "Invoice" # Use subscription_first_invoice_id + subscription_first_invoice, NOT THIS

  has_many :invoice_paid_features
  has_many :paid_features, through: :invoice_paid_features
  has_many :payments

  validates_presence_of :organization_id

  before_save :set_calculated_attributes

  scope :first_invoice, -> { where(first_invoice_id: nil) }
  scope :renewal_invoice, -> { where.not(first_invoice_id: nil) }
  scope :active, -> { where(is_active: true).where.not(subscription_start_at: nil) }
  scope :current, -> { active.where("subscription_end_at > ?", Time.now) }
  scope :expired, -> { active.where("subscription_end_at < ?", Time.now) }

  def subscription_duration; 1.year end # Static, at least for now
  def renewal_invoice?; first_invoice_id.present? end
  def active?; is_active && subscription_start_at.present? end # Alias - don't directly access the db attribute, because it might change
  def current?; active? && subscription_end_at > Time.now end
  def expired?; active? && !current? end
  def discount; features_at_start_cents end
  def paid_in_full?; amount_paid_cents.present? && amount_due_cents.present? && amount_paid_cents >= amount_due_cents end
  def subscription_first_invoice_id; first_invoice_id || id end
  def subscription_first_invoice; first_invoice || self end
  def subscription_invoices; self.class.where(first_invoice_id: subscription_first_invoice_id) end

  # There can be multiple features of the same id. View the spec for additional info
  def paid_feature_ids=(val) # This isn't super efficient, but whateves
    val = val.to_s.split(",") unless val.is_a?(Array)
    new_features = val.map { |v| PaidFeature.friendly_find(v) }.compact
    new_feature_ids = new_features.map(&:id)
    existing_feature_ids = invoice_paid_features.pluck(:paid_feature_id)
    (existing_feature_ids - new_feature_ids).uniq.each do |absent_id| # ids absent from new features
      invoice_paid_features.where(paid_feature_id: absent_id).delete_all
    end
    new_feature_ids.uniq.each do |feature_id|
      new_matching_ids = new_feature_ids.select { |i| i == feature_id }
      existing_matching_ids = existing_feature_ids.select { |i| i == feature_id }
      if new_matching_ids.count > existing_matching_ids.count
        (new_matching_ids.count - existing_matching_ids.count).times do
          invoice_paid_features.create(paid_feature_id: feature_id)
        end
      elsif new_matching_ids.count < existing_matching_ids.count
        (existing_matching_ids.count - new_matching_ids.count).times do
          invoice_paid_features.where(paid_feature_id: feature_id).first.delete
        end
      end
    end
    self.amount_due_cents = new_features.map(&:amount_cents).sum
  end

  def previous_invoice
    return nil unless renewal_invoice?
    subscription_invoices.where("id < ?", id).order(:id).last || subscription_first_invoice
  end

  def following_invoice
    subscription_invoices.where("id > ?", id).order(:id).first
  end

  def feature_cost_cents
    paid_features.sum(:amount_cents)
  end

  def create_following_invoice
    return nil unless active?
    return following_invoice if following_invoice.present?
    new_invoice = organization.invoices.create(subscription_start_at: subscription_end_at,
                                               first_invoice_id: subscription_first_invoice_id)
    new_invoice.paid_feature_ids = paid_features.recurring.pluck(:id)
    new_invoice.reload
    new_invoice
  end

  def set_calculated_attributes
    self.amount_paid_cents = payments.sum(:amount_cents)
    self.is_active = force_active || paid_in_full?
    if subscription_start_at.present?
      self.subscription_end_at ||= subscription_start_at + subscription_duration
    end
    true # TODO: Rails 5 update
  end
end
