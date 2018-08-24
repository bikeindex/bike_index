class LockType < ActiveRecord::Base
  include FriendlySlugFindable

  def self.old_attr_accessible
    %w(name slug).map(&:to_sym).freeze
  end
end
