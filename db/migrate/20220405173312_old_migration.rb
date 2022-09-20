class OldMigration < ActiveRecord::Migration[6.1]
  REQUIRED_VERSION = 20220324004315
  def up
    if ActiveRecord::Migrator.current_version < REQUIRED_VERSION
      raise StandardError, "`rails db:schema:load` must be run prior to `rails db:migrate`"
    end
  end
end
