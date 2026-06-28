class ReplaceRegistrationSequencePageBulletPointsWithBody < ActiveRecord::Migration[8.1]
  def change
    remove_column :registration_sequence_pages, :bullet_points, :text, array: true, default: []
    add_column :registration_sequence_pages, :body, :text
  end
end
