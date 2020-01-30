class DropFreedbackHashText < ActiveRecord::Migration[4.2]
  def change
    remove_column :feedbacks, :feedback_hash_text, :text
  end
end
