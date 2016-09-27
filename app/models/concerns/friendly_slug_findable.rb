module FriendlySlugFindable
  extend ActiveSupport::Concern
  module ClassMethods
    def friendly_find(n)
      return nil if n.blank?
      return where(id: n).first if n.is_a?(Integer) || n.match(/\A\d*\z/).present?
      find_by_slug(Slugifyer.slugify(n)) || where('lower(name) = ?', n.downcase.strip).first
    end
  end
  included do
    before_create :set_slug
  end

  def to_param
    slug
  end

  def set_slug
    self.slug ||= Slugifyer.slugify(name)
  end
end
