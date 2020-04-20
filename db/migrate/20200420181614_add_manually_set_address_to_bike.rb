class AddManuallySetAddressToBike < ActiveRecord::Migration[5.2]
  def change
    add_column :bikes, :address_set_manually, :boolean, default: false
  end
end
