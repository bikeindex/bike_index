class HandlebarType < ActiveRecord::Base
  def self.old_attr_accessible
    %w(name slug)
  end
  validates_presence_of :name, :slug
  validates_uniqueness_of :name, :slug
  has_many :bikes
end
