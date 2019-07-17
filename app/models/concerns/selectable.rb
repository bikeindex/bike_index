module Selectable
  extend ActiveSupport::Concern

  class_methods do
    def name_translation(name, locale: nil)
      I18n.t(
        name.to_s.downcase.gsub(/[^[:alnum:]]+/, "_"),
        scope: [:activerecord, :select_options, self.name.underscore],
        locale: locale,
      )
    end

    def select_options(locale: nil)
      pluck(:id, :name).map { |id, name| [name_translation(name, locale: locale), id] }
    end
  end
end
