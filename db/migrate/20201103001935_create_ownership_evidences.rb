class CreateOwnershipEvidences < ActiveRecord::Migration[5.2]
  def change
    create_table :ownership_evidences do |t|

      t.timestamps
    end
  end
end
