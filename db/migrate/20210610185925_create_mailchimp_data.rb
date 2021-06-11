class CreateMailchimpData < ActiveRecord::Migration[5.2]
  def change
    create_table :mailchimp_data do |t|
      t.references :user, index: true
      t.datetime :user_deleted_at
      t.string :email
      t.integer :status
      t.jsonb :data

      t.timestamps
    end

    add_reference :feedbacks, :mailchimp_datum, index: true
  end
end
