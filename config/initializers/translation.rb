# frozen_string_literal: true

TranslationIO.configure do |config|
  config.api_key = ENV["TRANSLATION_IO_API_KEY"]
  config.source_locale = "en"
  config.target_locales = %w[es it nl nb]

  # Uncomment this if you don't want to use gettext
  config.disable_gettext = true

  # Uncomment this if you already use gettext or fast_gettext
  # config.locales_path = File.join('path', 'to', 'gettext_locale')

  # Find other useful usage information here:
  # https://github.com/translation/rails#readme
end

#
# TODO: remove after updating to Ruby 3.1 - #2605
# added these methods in #2609 to make the update backward compatible
# (See also i18n_spec.rb and application_helper.rb)
#
# i18n_translate_with_args( replaced I18n.t(
def i18n_translate_with_args(key, ...)
  I18n.t(key, ...)
end

# translation_with_args( replaced translation(
def translation_with_args(key, ...)
  I18n.t(key, ...)
end
