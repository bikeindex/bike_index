# frozen_string_literal: true

class PaidFeature < ActiveRecord::Base
  include FriendlySlugFindable
  include Amountable
  KIND_ENUM = { standard: 0, standard_one_time: 1, custom: 2, custom_one_time: 3 }.freeze

  has_many :invoice_paid_features
  has_many :invoices, through: :invoice_paid_features
  validates_uniqueness_of :name

  enum kind: KIND_ENUM

  before_validation :set_calculated_attributes

  scope :recurring, -> { where(kind: %w[standard custom]) }
  scope :upfront, -> { where(kind: %w[standard_upfront custom_upfront]) }

  def one_time?; standard_one_time? || custom_one_time? end
  def recurring?; !one_time? end

  def set_calculated_attributes
    self.slug = Slugifyer.slugify(name)
  end
end
