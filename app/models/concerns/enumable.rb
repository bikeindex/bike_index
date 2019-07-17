module Enumable
  extend ActiveSupport::Concern

  class_methods do
    def slug_translation(slug, locale: nil)
      I18n.t(
        slug.to_s.underscore,
        scope: [:activerecord, :enums, self.name.underscore],
        locale: locale,
      )
    end

    def select_options(locale: nil)
      slugs.map { |slug| [slug_translation(slug, locale: locale), slug] }
    end

    def legacy_selections(locale: nil)
      slugs.map { |slug| { slug: slug, name: slug_translation(slug, locale: locale) } }
    end

    def slugs
      self::SLUGS.keys.map(&:to_s)
    end

    def friendly_find(str)
      return unless str.present?
      str = str.downcase.strip
      slug = (slugs & [str]).first
      slug ||= self::NAMES.detect do |k, v|
        ([k.to_s, v.downcase] + v.downcase.strip.split(" or ")).include?(str)
      end&.first
      new(slug.to_sym) if slug.present?
    end
  end

  def name
    self.class::NAMES[slug]
  end
end
