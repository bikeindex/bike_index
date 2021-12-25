class CreateUserRegistrationOrganizations < ActiveRecord::Migration[5.2]
  def change
    create_table :user_registration_organizations do |t|
      t.references :user, index: true
      t.references :organization, index: true
      t.boolean :all_bikes, default: false
      t.jsonb :bike_ids
      t.jsonb :registration_info
      t.deleted_at :datetime

      t.timestamps
    end
  end
end
