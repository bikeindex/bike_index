DESCRIPTION = <<~MD
  - **5,000 Ad Campaign Views** from people within 10 miles
  - **+10,000 Bonus Views** from people within 10 miles
  - Ad campaign runs for **7 Days**
  - **Priority Support** from the Bike Index Team
MD

PRICING_PLANS = [
  {
    views: 50_000,
    duration_days: 7,
    amount_cents: 6995,
    name: "Maximum",
    description: DESCRIPTION,
  },
  {
    views: 25_000,
    duration_days: 7,
    amount_cents: 3995,
    name: "Standard",
    description: DESCRIPTION,
  },
  {
    views: 10_000,
    duration_days: 7,
    amount_cents: 1995,
    name: "Starter",
    description: DESCRIPTION,
  },
]

class TheftAlertPlan < ActiveRecord::Base
  include Amountable

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

  def self.seed_plans
    delete_all
    PRICING_PLANS.map { |attr| create(attr) }
  end

  def description_html
    Kramdown::Document.new(description).to_html
  end
end
