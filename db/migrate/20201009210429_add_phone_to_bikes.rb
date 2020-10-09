class AddPhoneToBikes < ActiveRecord::Migration[5.2]
  def change
    add_column :bikes, :phone, :string
    add_column :ownerships, :is_phone, :boolean, default: false
  end
end
