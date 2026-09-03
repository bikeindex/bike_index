class AddBinxDataToActiveStorageBlobs < ActiveRecord::Migration[8.0]
  # ActiveStorage's metadata is a text column it serializes itself, and it permits whatever the
  # client posts into it - PROTECTED_METADATA only covers Rails' own keys. Our references to the
  # records a blob belongs to get their own jsonb column, out of that namespace and queryable.
  def change
    add_column :active_storage_blobs, :binx_data, :jsonb
  end
end
