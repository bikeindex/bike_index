class AddReferralSourceToPayments < ActiveRecord::Migration[6.1]
  def change
    add_column :payments, :referral_source, :text
  end
end
