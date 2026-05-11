module FriendlyNameFindable
  extend ActiveSupport::Concern

  module ClassMethods
    def friendly_find(str)
      str = normalize_friendly_str(str)
      return nil if str.blank?
      return where(id: str).first if integer_string?(str)

      where("lower(name) = ?", str.downcase).first
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

    def normalize_friendly_str(str)
      str.is_a?(String) ? Binxtils::InputNormalizer.string(str) : str
    end
  end
end
