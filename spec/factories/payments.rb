# == Schema Information
#
# Table name: payments
#
#  id                     :integer          not null, primary key
#  amount_cents           :integer
#  currency_enum          :integer
#  email                  :string(255)
#  kind                   :integer
#  paid_at                :datetime
#  payment_method         :integer          default("stripe")
#  referral_source        :text
#  stripe_status          :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  invoice_id             :integer
#  membership_id          :bigint
#  organization_id        :integer
#  stripe_id              :string(255)
#  stripe_subscription_id :bigint
#  user_id                :integer
#
# Indexes
#
#  index_payments_on_membership_id           (membership_id)
#  index_payments_on_stripe_subscription_id  (stripe_subscription_id)
#  index_payments_on_user_id                 (user_id)
#
FactoryBot.define do
  factory :payment do
    user { FactoryBot.create(:user) }
    amount_cents { 999 }
    payment_method { "stripe" }
    paid_at { Time.current }
    factory :payment_check do
      payment_method { "check" }
    end
  end
end
