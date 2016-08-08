class LockType < ActiveRecord::Base
  include FriendlySlugFindable

  def self.old_attr_accessible
    %w(name slug).map(&:to_sym).freeze
  end
  validates_presence_of :name
  validates_uniqueness_of :name, :slug
end
