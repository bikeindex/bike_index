class AddPoliceDepartmentToStolenRecord < ActiveRecord::Migration
  def change
    add_column :stolenRecords, :police_report_department, :string
  end
end
