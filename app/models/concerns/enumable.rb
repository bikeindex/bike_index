module Enumable
  extend ActiveSupport::Concern

  class_methods do
    def select_options
      Array(self::NAMES.invert)
    end

    def legacy_selections
      self::NAMES.map { |k, v| { slug: k.to_s, name: v } }
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