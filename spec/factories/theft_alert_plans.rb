# == Schema Information
#
# Table name: theft_alert_plans
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
FactoryBot.define do
  factory :theft_alert_plan do
    sequence(:name) { |n| "Theft Alert Plan #{n.to_s.rjust(3, "0")}" }
    sequence(:amount_cents) { |n| n * 100 }
    views { 50_000 }
    duration_days { 7 }
    active { true }
  end
end
