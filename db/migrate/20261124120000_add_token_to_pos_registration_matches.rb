class AddTokenToPosRegistrationMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :pos_registration_matches, :token, :string
    add_index :pos_registration_matches, :token, unique: true
  end
end
