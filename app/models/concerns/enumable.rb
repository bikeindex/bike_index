module Enumable
  extend ActiveSupport::Concern

  class_methods do
    def slug_translation(slug)
      I18n.t(
        slug.to_s.underscore,
        scope: [:activerecord, :enums, name.underscore]
      )
    end

    def slug_translation_short(slug)
      slug_translation(slug)&.gsub(/\s?\([^)]*\)/i, "")
    end

    def select_options
      slugs.map { |slug| [slug_translation(slug), slug] }
    end

    def slug_translation_hash_lowercase_short
      select_options.to_h { |x| [x[1], x[0].downcase.split("(").first.strip] }
    end

    def legacy_selections
      slugs.map { |slug| {slug: slug, name: slug_translation(slug)} }
    end

    def slugs_sym
      self::SLUGS.keys
    end

    def slugs
      slugs_sym.map(&:to_s)
    end

    def all
      slugs_sym.map { |s| new(s) }
    end

    def find(str)
      new(self::SLUGS.key(str))
    end

    def find_sym(str)
      return if str.blank?
      return str.slug if str.instance_of?(self)
      return str if str.is_a?(Symbol) && self::SLUGS.key?(str)
      str = str.to_s.downcase.strip if str.is_a?(String) || str.is_a?(Symbol)
      if str.is_a?(Integer) || str.match?(/\A\d+\z/)
        str = str.to_i if str.is_a?(String)
        matching_sym = self::SLUGS.key(str)
        return matching_sym if matching_sym.present?
      end
      slug = (slugs & [str]).first
      slug ||= self::NAMES.detect do |k, v|
        v_down = v.downcase
        (
          [k.to_s, v_down] + v_down.delete(")").split("(").map(&:strip) +
          v_down.strip.split(" or ")
        ).include?(str)
      end&.first
      slug&.to_sym
    end

    def friendly_find(str)
      matching_sym = find_sym(str)
      matching_sym.present? ? new(matching_sym) : nil
    end
  end

  def name
    self.class::NAMES[slug]
  end
end
