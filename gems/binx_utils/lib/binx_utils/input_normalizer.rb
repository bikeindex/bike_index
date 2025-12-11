# frozen_string_literal: true

require "rails-html-sanitizer"

module BinxUtils
  class InputNormalizer
    class << self
      def boolean(param = nil)
        return false if param.blank?

        ActiveModel::Type::Boolean.new.cast(param.to_s.strip)
      end

      def string(val)
        return nil if val.blank?

        val.strip.gsub(/\s+/, " ")
      end

      def present_or_false?(val)
        val.to_s.present?
      end

      def sanitize(str = nil)
        Rails::HTML::Sanitizer.full_sanitizer.new.sanitize(str.to_s, encode_special_chars: true)
          .strip
          .gsub("&amp;", "&")
          .gsub(/\s+/, " ")
      end

      def regex_escape(val)
        string(val)&.gsub(/\W/, ".")
      end
    end
  end
end
