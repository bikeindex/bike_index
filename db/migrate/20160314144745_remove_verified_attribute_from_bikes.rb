class RemoveVerifiedAttributeFromBikes < ActiveRecord::Migration
  def up
    remove_column :bikes, :verified
    remove_column :bikes, :paid_for
  end

  def down
    add_column :bikes, :verified, :boolean
    add_column :bikes, :paid_for, :boolean
  end
end
