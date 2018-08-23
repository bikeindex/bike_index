class HandlebarType < ActiveRecord::Base
  include FriendlySlugFindable
  has_many :bikes

  def self.other
    where(name: 'Not handlebars', slug: 'other').first_or_create
  end

  def self.flat
    where(name: 'Flat or riser', slug: 'flat').first_or_create
  end
end
