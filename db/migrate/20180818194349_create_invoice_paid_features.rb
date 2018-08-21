class CreateInvoicePaidFeatures < ActiveRecord::Migration
  def change
    create_table :invoice_paid_features do |t|
      t.references :invoice, index: true
      t.references :paid_feature, index: true

      t.timestamps null: false
    end
  end
end
