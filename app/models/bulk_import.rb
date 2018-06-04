class BulkImport < ActiveRecord::Base
  belongs_to :organization
  belongs_to :user

  def file_import_errors
    import_errors[:file]
  end

  def line_import_errors
    import_errors[:line]
  end
end
