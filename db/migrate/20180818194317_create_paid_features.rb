class CreatePaidFeatures < ActiveRecord::Migration
  def change
    create_table :paid_features do |t|

      t.timestamps null: false
    end
  end
end
