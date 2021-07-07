class TheftAlertPlan < ApplicationRecord
  include Amountable
  include Localizable

  validates :name,
    :amount_cents,
    :currency,
    :views,
    :duration_days,
    presence: true

  validates :amount_cents, :duration_days, :views, numericality: {greater_than: 0}

  has_many :theft_alerts, dependent: :destroy
  has_many :stolen_records, through: :theft_alerts

  scope :active, -> { where(active: true) }
  scope :price_ordered_desc, -> { order(amount_cents: :desc) }
  scope :price_ordered_asc, -> { order(amount_cents: :asc) }

  def description_html
    Kramdown::Document.new(description).to_html
  end

  # Because it takes a little while to get the ad started
  def duration_days_facebook
    duration_days + 1
  end

  def amount_facebook
    self.class.money_formatted(amount_cents_facebook)
  end
end
