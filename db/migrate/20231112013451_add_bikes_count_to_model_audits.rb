class AddBikesCountToModelAudits < ActiveRecord::Migration[6.1]
  def change
    add_column :model_audits, :bikes_count, :integer
  end
end
