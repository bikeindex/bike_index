module LocaleHelper
  def locale_names
    I18n.available_locales.map do |locale|
      { name: I18n.t('language', locale: locale), code: locale.to_s }
    end
  end
end
