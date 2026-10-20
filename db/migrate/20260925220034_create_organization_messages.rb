class CreateOrganizationMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_messages do |t|
      t.references :bike, null: false
      t.references :organization, null: false
      t.references :sender, null: false
      t.references :receiver
      t.string :receiver_email
      t.text :message

      t.timestamps
    end
  end
end
