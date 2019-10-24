# Add to a model that can be localized independent of the locale but with the
# same set of languages (e.g. News, TheftAlertPlan models).
#
# Expects a `language` column defined on the corresponding table.
module Localizable
  extend ActiveSupport::Concern

  included do
    enum language: I18n.available_locales.sort.map.with_index.to_h.freeze

    scope :in_language, ->(code) { where(language: languages[code.presence || I18n.locale.to_s]) }
  end
end
