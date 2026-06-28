class CreateSsoIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :sso_identities do |t|
      t.references :user, index: true
      t.references :organization, index: true
      t.string :provider
      t.string :uid
      t.string :email
      t.datetime :last_sign_in_at
      t.string :name_id_format

      t.timestamps
    end
    add_index :sso_identities, %i[organization_id provider uid], unique: true
  end
end
