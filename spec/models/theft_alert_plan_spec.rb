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
require "rails_helper"

RSpec.describe TheftAlertPlan, type: :model do
  it_behaves_like "amountable"
  it_behaves_like "currencyable"
end
