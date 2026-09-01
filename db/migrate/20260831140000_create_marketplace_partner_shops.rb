class CreateMarketplacePartnerShops < ActiveRecord::Migration[8.1]
  def change
    create_table :marketplace_partner_shops do |t|
      t.references :organization, null: false, index: {unique: true}
      # which of the organization's locations takes drop-offs
      t.references :location

      t.integer :status
      t.integer :booked_by

      t.integer :boxing_fee_cents
      t.integer :currency_enum
      t.integer :weekly_capacity

      t.timestamps
    end
  end
end
