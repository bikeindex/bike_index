class AddMergerToPosRegistrationMatches < ActiveRecord::Migration[8.1]
  def change
    add_reference :pos_registration_matches, :merger, index: true
    add_column :pos_registration_matches, :merged_at, :datetime
  end
end
