class HandlebarType < ActiveRecord::Base
  include FriendlySlugFindable
  validates_presence_of :name, :slug
  validates_uniqueness_of :name, :slug
  has_many :bikes

  class << self
    def other
      where(name: 'Not handlebars', slug: 'other').first_or_create
    end

    def flat
      where(name: 'Flat or riser', slug: 'flat').first_or_create
    end
  end
end
