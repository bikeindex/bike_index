module FriendlyNameFindable
  extend ActiveSupport::Concern

  module ClassMethods
    def friendly_find(str)
      return nil if str.blank?
      strip_if_str!(str)
      return where(id: str).first if integer_string?(str)
      where("lower(name) = ?", str.downcase.strip).first
    end

    def friendly_find!(str)
      friendly_find(str) || (raise ActiveRecord::RecordNotFound)
    end

    def friendly_find_id(str)
      friendly_find(str)&.id
    end

    def integer_string?(str)
      str.is_a?(Integer) || str.match(/\A\d+\z/).present?
    end

    def strip_if_str!(str)
      str.strip! if str.is_a?(String) && !str.frozen?
    end
  end
end
