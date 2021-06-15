class CreateMailchimpValues < ActiveRecord::Migration[5.2]
  def change
    create_table :mailchimp_values do |t|
      t.integer :list
      t.integer :kind
      t.string :name
      t.string :slug
      t.string :mailchimp_id
      t.jsonb :data

      t.timestamps
    end
  end
end
