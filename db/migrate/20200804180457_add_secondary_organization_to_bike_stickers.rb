class AddSecondaryOrganizationToBikeStickers < ActiveRecord::Migration[5.2]
  def change
    add_reference :bike_stickers, :secondary_organization, index: true
  end
end
