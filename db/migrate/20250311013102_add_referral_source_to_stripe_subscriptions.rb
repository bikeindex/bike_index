class AddReferralSourceToStripeSubscriptions < ActiveRecord::Migration[8.0]
  def change
    add_column :stripe_subscriptions, :referral_source, :text
  end
end
