class HandlebarType < ActiveRecord::Base
  include FriendlySlugFindable
  validates_presence_of :name, :slug
  validates_uniqueness_of :name, :slug
  has_many :bikes

  class << self
    def other
      where(name: 'Not handlebars', slug: 'other').first_or_create
    end
    def old_attr_accessible
      %w(name slug).map(&:to_sym).freeze
    end
  end
end
