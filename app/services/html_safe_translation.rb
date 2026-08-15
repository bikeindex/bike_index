# frozen_string_literal: true

# The `_html` half of Rails' `t` helper, for the `translation` wrappers in
# ApplicationComponent and ControllerHelpers - which each resolve a scope their own way,
# then hand the lookup here
module HtmlSafeTranslation
  extend Functionable

  def translate(key, scope:, **kwargs)
    scope = scope.compact
    return I18n.t(key, **kwargs, scope:) unless key.to_s.end_with?("_html")

    I18n.t(key, **escaped_interpolations(kwargs), scope:).html_safe
  end

  #
  # private below here
  #

  # Rails escapes what it interpolates into an _html key; match it so a caller passing
  # user-entered text doesn't emit it raw
  def escaped_interpolations(kwargs)
    kwargs.to_h do |name, value|
      skip = I18n::RESERVED_KEYS.include?(name) || (name == :count && value.is_a?(Numeric))
      [name, skip ? value : ERB::Util.html_escape(value)]
    end
  end

  conceal :escaped_interpolations
end
