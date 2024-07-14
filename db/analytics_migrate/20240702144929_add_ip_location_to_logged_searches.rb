class AddIpLocationToLoggedSearches < ActiveRecord::Migration[6.1]
  def change
    add_column :logged_searches, :street, :string
    add_column :logged_searches, :neighborhood, :string
    add_column :logged_searches, :city, :string
    add_column :logged_searches, :zipcode, :string
    add_reference :logged_searches, :country
    add_reference :logged_searches, :state

    add_column :logged_searches, :processed, :boolean, default: false
  end
end
