class RenameCmodelName < ActiveRecord::Migration[5.2]
  def change
    rename_column :components, :cmodel_name, :component_model
  end
end
