module FriendlyNameFindable
  extend ActiveSupport::Concern
  module ClassMethods
    def friendly_find(n)
      return nil if n.blank?
      return where(id: n).first if n.is_a?(Integer) || n.match(/\A\d*\z/).present?
      where('lower(name) = ?', n.downcase.strip).first
    end

    def friendly_id_find(n)
      m = friendly_find(n)
      m && m.id
    end
  end
end
