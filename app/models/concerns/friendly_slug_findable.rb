module FriendlySlugFindable
  extend ActiveSupport::Concern
  include FriendlyNameFindable

  module ClassMethods
    def friendly_find(n)
      return nil if n.blank?
      return where(id: n).first if n.is_a?(Integer) || n.strip.match(/\A\d+\z/).present?
      find_by_slug(Slugifyer.slugify(n)) || where("lower(name) = ?", n.downcase.strip).first
    end

    def friendly_find_id(str)
      o = friendly_find(str)
      o.present? ? o.id : nil
    end
  end

  included do
    validates_presence_of :name
    validates_uniqueness_of :name, :slug

    before_create :set_slug
  end

  def to_param
    slug
  end

  def set_slug
    self.name = name&.strip
    self.slug ||= Slugifyer.slugify(name)
  end
end
