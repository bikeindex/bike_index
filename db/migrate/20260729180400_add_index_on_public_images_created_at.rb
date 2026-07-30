class AddIndexOnPublicImagesCreatedAt < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # The admin index filters and sorts on created_at, which was a sequential scan
    add_index :public_images, :created_at, algorithm: :concurrently
  end
end
