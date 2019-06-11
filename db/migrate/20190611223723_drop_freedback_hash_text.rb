class DropFreedbackHashText < ActiveRecord::Migration
  def change
    remove_column :feedbacks, :feedback_hash_text, :text
  end
end
