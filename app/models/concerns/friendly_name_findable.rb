module FriendlyNameFindable
  extend ActiveSupport::Concern

  module ClassMethods
    def friendly_find(n)
      return nil if n.blank?
      return where(id: n).first if n.is_a?(Integer) || n.match(/\A\d+\z/).present?
      where("lower(name) = ?", n.downcase.strip).first
    end

    def friendly_find!(str)
      friendly_find(str) || (raise ActiveRecord::RecordNotFound)
    end

    def friendly_find_id(n)
      friendly_find(n)&.id
    end
  end
end
