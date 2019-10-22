class TheftAlertPlan < ActiveRecord::Base
  include Amountable
  include Localizable

  validates :name,
            :amount_cents,
            :views,
            :duration_days,
            presence: true

  validates :amount_cents, :duration_days, :views, numericality: { greater_than: 0 }

  has_many :theft_alerts, dependent: :destroy
  has_many :stolen_records, through: :theft_alerts

  scope :active, -> { where(active: true) }
  scope :price_ordered_desc, -> { order(amount_cents: :desc) }
  scope :price_ordered_asc, -> { order(amount_cents: :asc) }

  def description_html
    Kramdown::Document.new(description).to_html
  end
end
