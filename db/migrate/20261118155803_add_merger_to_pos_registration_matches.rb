class AddMergerToPosRegistrationMatches < ActiveRecord::Migration[8.1]
  def change
    add_reference :pos_registration_matches, :merger, index: true
  end
end
