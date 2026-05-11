module FriendlySlugFindable
  extend ActiveSupport::Concern
  include FriendlyNameFindable

  module ClassMethods
    def friendly_find(str)
      str = normalize_friendly_str(str)
      return nil if str.blank?
      return where(id: str).first if integer_string?(str)

      find_by_slug(Slugifyer.slugify(str)) || where("lower(name) = ?", str.downcase).first
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
