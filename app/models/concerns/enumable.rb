module Enumable
  extend ActiveSupport::Concern

  class_methods do
    def slug_translation(slug)
      I18n.t(
        slug.to_s.underscore,
        scope: [:activerecord, :enums, name.underscore]
      )
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

      slug = Slugifyer.slugify(str)
      return self::SLUGS.key(slug.to_i) if slug.match?(/\A\d+\z/)

      key_for(Slugifyer.slugify(str.to_s.tr("()", " "))) || key_for(slug)
    end

    def friendly_find(str)
      matching_sym = find_sym(str)
      matching_sym.present? ? new(matching_sym) : nil
    end

    private

    def key_for(slug) = names_and_secondary_names.detect { |_, names| names.include?(slug) }&.first

    def names_and_secondary_names
      @names_and_secondary_names ||= self::NAMES.to_h do |k, v|
        [k, [k, v.tr("()", " "), *secondary_names_for(v.downcase)].map { Slugifyer.slugify(it) }.uniq]
      end
    end

    def ignored_secondaries
      ["etc"].freeze
    end

    def secondary_names_for(name_downcase)
      primary, *secondaries = name_downcase.delete(")").split("(").map(&:strip)
      secondaries = secondaries.map do |str|
        str.split(",").map { it.gsub("e.g.", "").strip }
      end.flatten - ignored_secondaries

      [primary] + secondaries
    end
  end

  def name
    self.class::NAMES[slug]
  end
end
