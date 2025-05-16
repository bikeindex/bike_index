class CreateMarketplaceMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :marketplace_messages do |t|
      t.references :marketplace_listing
      t.references :initial_record
      t.references :sender
      t.references :receiver

      t.text :subject
      t.text :body
      t.integer :kind
      t.integer :messages_prior_count

      t.timestamps
    end
  end
end
