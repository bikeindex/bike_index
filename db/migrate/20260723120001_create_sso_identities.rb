class CreateSsoIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :sso_identities do |t|
      t.references :user, null: false, index: true
      # No standalone index - the composite unique index below starts with organization_id
      t.references :organization, null: false, index: false
      # provider/uid are the unique index below - NULLs don't collide in Postgres,
      # so a nullable column would silently stop enforcing uniqueness
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :email
      t.datetime :last_sign_in_at
      t.string :name_id_format

      t.timestamps
    end
    add_index :sso_identities, %i[organization_id provider uid], unique: true
  end
end
