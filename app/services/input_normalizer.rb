class InputNormalizer
  class << self
    def boolean(param = nil)
      return false if param.blank?
      ActiveRecord::Type::Boolean.new.cast(param.to_s.strip)
    end

    def string(val)
      return nil if val.blank?
      val.strip.gsub(/\s+/, " ")
    end

    def present_or_false?(val)
      val.to_s.present?
    end

    def sanitize(str = nil)
      Rails::Html::Sanitizer.full_sanitizer.new.sanitize(str.to_s, encode_special_chars: true)
        .strip
        .gsub("&amp;", "&") # ampersands are commonly used - keep them normal
        .gsub(/\s+/, " ") # remove extra whitespace
    end

    def regex_escape(val)
      # Lazy hack, good enough for current purposes. Improve if required!
      string(val)&.gsub(/\W/, ".")
    end
  end
end
