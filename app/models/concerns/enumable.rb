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

      str = str.to_s.downcase.strip.tr("_", "-") if str.is_a?(String) || str.is_a?(Symbol)
      if str.is_a?(Integer) || str.match?(/\A\d+\z/)
        str = str.to_i if str.is_a?(String)
        matching_sym = self::SLUGS.key(str)
        return matching_sym if matching_sym.present?
      end
      slug = (slugs & [str]).first
      slug ||= names_and_secondary_names.detect { |names| names.include?(str) }&.first
      if slug.blank? && str[/\(/].present?
        str = str.split("(").first.strip
        slug = names_and_secondary_names.detect { |names| names.include?(str) }&.first
      end
      slug&.to_sym
    end

    def friendly_find(str)
      matching_sym = find_sym(str)
      matching_sym.present? ? new(matching_sym) : nil
    end

    private

    def names_and_secondary_names
      @names_and_secondary_names ||= self::NAMES.map do |k, v|
        v_down = v.downcase
        secondary_names = v_down[/\(/].present? ? secondary_names_for(v_down) : []

        ([k.to_s, v_down] + secondary_names).uniq
      end
    end

    def ignored_secondaries
      ["etc"].freeze
    end

    def secondary_names_for(name_downcase)
      return [] unless name_downcase[/\(/].present?
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
