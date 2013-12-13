class AddPoliceDepartmentToStolenRecord < ActiveRecord::Migration
  def change
    add_column :stolen_records, :police_report_department, :string
  end
end
