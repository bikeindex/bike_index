class CreateMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :memberships do |t|
      t.references :user, index: true
      t.integer :kind
      t.datetime :start_at
      t.datetime :end_at

      t.timestamps
    end
  end
end
