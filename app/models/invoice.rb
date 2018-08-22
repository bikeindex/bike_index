# frozen_string_literal: true

class Invoice < ActiveRecord::Base
  scope :initial, -> { where(renews_subscription_id: nil) }
  scope :renewal, -> { where.not(renews_subscription_id: nil) }
  scope :current, -> { where("subscription_end_at > ?", Time.now) }
  scope :expired, -> { where("subscription_end_at < ?", Time.now) }

  belongs_to :organization
  belongs_to :subscription_first_invoice, class_name: "Invoice"

  before_save :set_calculated_attributes

  def subscription_duration; 1.year end # Static, at least for now
  def initial?; renews_subscription_id.present? end
  def renewal?; !initial? end
  def current?; subscription_end_at > Time.now end
  def expired?; !current? end

  def set_calculated_attributes
    self.subscription_end_at = subscription_start_at + subscription_duration
  end
end
