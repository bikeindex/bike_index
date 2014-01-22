class AddLocationInformationToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :creation_zipcode, :string
    add_column :bikes, :creation_country_id, :integer
    add_column :bikes, :country_id, :integer
  end
end
