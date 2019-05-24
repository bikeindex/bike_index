class AddRecoveringUserIdToStolenRecords < ActiveRecord::Migration
  def change
    change_table(:stolen_records) do |t|
      t.references(:recovering_user, index: true)
    end
  end
end
