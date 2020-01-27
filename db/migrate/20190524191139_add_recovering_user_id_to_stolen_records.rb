class AddRecoveringUserIdToStolenRecords < ActiveRecord::Migration[4.2]
  def change
    change_table(:stolen_records) do |t|
      t.references(:recovering_user, index: true)
    end
  end
end
