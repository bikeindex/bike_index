# frozen_string_literal: true

class PaidFeature < ActiveRecord::Base
  include Amountable
  KIND_ENUM = { standard: 0, standard_one_time: 1, custom: 2, custom_one_time: 3 }.freeze
  # Just to keep track of this somewhere - every paid feature that is locked should be in this array
  # These slugs are used in the code (e.g. in the views)
  EXPECTED_SLUGS = %w[csv_exports messages geolocated_messages abandoned_bike_messages reg_address reg_secondary_serial].freeze

  has_many :invoice_paid_features
  has_many :invoices, through: :invoice_paid_features
  validates_uniqueness_of :name

  enum kind: KIND_ENUM

  after_commit :update_invoices

  scope :recurring, -> { where(kind: %w[standard custom]) }
  scope :upfront, -> { where(kind: %w[standard_upfront custom_upfront]) }

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  def one_time?; standard_one_time? || custom_one_time? end
  def recurring?; !one_time? end

  def locked?
    feature_slugs.any? && invoices.active.any?
  end

  def feature_slugs_string
    feature_slugs.join(", ")
  end

  def feature_slugs_string=(val)
    self.feature_slugs = val.split(",").reject(&:blank?).map do |str|
      fslug = str.downcase.strip
      EXPECTED_SLUGS.include?(fslug) ? fslug : nil
    end.compact
  end

  # Trigger an update to invoices which will, in turn, update the associated organizations
  def update_invoices
    invoices.each { |i| i.update_attributes(updated_at: Time.now) }
  end
end
