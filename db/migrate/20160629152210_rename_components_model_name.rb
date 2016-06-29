class RenameComponentsModelName < ActiveRecord::Migration
  def change
    rename_column :components, :model_name, :cmodel_name
  end
end
