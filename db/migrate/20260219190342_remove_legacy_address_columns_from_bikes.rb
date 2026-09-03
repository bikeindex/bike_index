class RemoveLegacyAddressColumnsFromBikes < ActiveRecord::Migration[8.1]
  def change
    change_table :bikes, bulk: true do |t|
      t.remove :street, type: :string
      t.remove :city, type: :string
      t.remove :zipcode, type: :string, limit: 255
      t.remove :neighborhood, type: :string
      t.remove :state_id, type: :bigint
      t.remove :country_id, type: :integer
    end
  end
end
