# frozen_string_literal: true

class PaidFeature < ActiveRecord::Base
  include FriendlySlugFindable
  include Amountable
  KIND_ENUM = { standard: 0, standard_one_time: 1, custom: 2, custom_one_time: 3 }.freeze
  # Just to keep track of this somewhere - every paid feature that is locked should be in this array
  # These slugs are used in the code (e.g. in the views)
  EXPECTED_LOCKED_SLUGS = %w[csv-exports].freeze

  has_many :invoice_paid_features
  has_many :invoices, through: :invoice_paid_features
  validates_uniqueness_of :name

  enum kind: KIND_ENUM

  before_validation :set_calculated_attributes
  after_commit :update_invoices

  scope :recurring, -> { where(kind: %w[standard custom]) }
  scope :upfront, -> { where(kind: %w[standard_upfront custom_upfront]) }

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  def one_time?; standard_one_time? || custom_one_time? end
  def recurring?; !one_time? end
  def locked?; is_locked end

  def set_calculated_attributes
    self.slug = Slugifyer.slugify(name)
  end

  # Trigger an update to invoices which will, in turn, update the associated organizations
  def update_invoices
    invoices.each { |i| i.update_attributes(updated_at: Time.now) }
  end
end
