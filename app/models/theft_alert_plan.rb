# == Schema Information
#
# Table name: theft_alert_plans
# Database name: primary
#
#  id                    :integer          not null, primary key
#  active                :boolean          default(TRUE), not null
#  ad_radius_miles       :integer
#  amount_cents          :integer          not null
#  amount_cents_facebook :integer
#  currency_enum         :integer
#  description           :string           default(""), not null
#  duration_days         :integer          not null
#  language              :integer          default("en"), not null
#  name                  :string           default(""), not null
#  views                 :integer          not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
class TheftAlertPlan < ApplicationRecord
  include Currencyable
  include Amountable
  include Translatable

  validates :name,
    :amount_cents,
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
end
