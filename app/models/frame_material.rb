class FrameMaterial < ActiveRecord::Base
  def self.old_attr_accessible
    %w(name slug)
  end
  validates_presence_of :name, :slug
  validates_uniqueness_of :name, :slug
  has_many :bikes

  default_scope { order("created_at desc") }

end
