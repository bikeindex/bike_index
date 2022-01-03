class CreateUserRegistrationOrganizations < ActiveRecord::Migration[5.2]
  def change
    create_table :user_registration_organizations do |t|
      t.references :user, index: true
      t.references :organization, index: true
      t.boolean :all_bikes, default: false
      t.boolean :can_not_edit_claimed, default: false
      t.jsonb :registration_info
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
