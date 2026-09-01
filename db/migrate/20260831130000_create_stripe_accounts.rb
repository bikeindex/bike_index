class CreateStripeAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :stripe_accounts do |t|
      # Sellers are Users, partner shops are Organizations
      t.references :account_holder, polymorphic: true

      t.string :stripe_id, index: {unique: true}
      t.boolean :charges_enabled, default: false, null: false
      t.boolean :payouts_enabled, default: false, null: false
      t.boolean :details_submitted, default: false, null: false
      t.datetime :onboarded_at

      t.timestamps
    end
  end
end
