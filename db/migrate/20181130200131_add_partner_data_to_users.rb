class AddPartnerDataToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :partner_data, :json
  end
end
