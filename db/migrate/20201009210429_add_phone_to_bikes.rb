class AddPhoneToBikes < ActiveRecord::Migration[5.2]
  def change
    add_column :bikes, :is_phone, :boolean, default: false
    add_column :ownerships, :is_phone, :boolean, default: false
  end
end
