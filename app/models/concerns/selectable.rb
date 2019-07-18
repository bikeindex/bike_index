module Selectable
  extend ActiveSupport::Concern

  class_methods do
    def name_translation(name)
      I18n.t(
        name.to_s.downcase.gsub(/[^[:alnum:]]+/, "_"),
        scope: [:activerecord, :select_options, self.name.underscore],
      )
    end

    def select_options
      pluck(:id, :name).map { |id, name| [name_translation(name), id] }
    end
  end
end
