class RenameCmodelName < ActiveRecord::Migration[5.2]
  def change
    # Also add this because I don't want to keep using cmodel in this PR
    rename_column :components, :cmodel_name, :cmodel_name, :string
  end
end
