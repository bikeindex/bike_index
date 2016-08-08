class Cgroup < ActiveRecord::Base
  # Note: Cgroup is short for component_group
  include FriendlySlugFindable

  class << self
    def old_attr_accessible
      %w(name slug description).map(&:to_sym).freeze
    end

    def additional_parts
      where(name: 'Additional parts').first_or_create
    end
  end

  validates_presence_of :name
  validates_uniqueness_of :name
  has_many :ctypes
end
