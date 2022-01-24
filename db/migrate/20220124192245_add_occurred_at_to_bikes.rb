class AddOccurredAtToBikes < ActiveRecord::Migration[5.2]
  def change
    add_column :bikes, :occurred_at, :timestamp
  end
end
