# Internationalization

## Storing the translations

## Locale file hierarchy

```
# config/locales

|-defaults
|--en.yml
|-flash
|--en.yml
|--es.yml
|-models
|-mailers
|-views
|--bikes
|--blogs
```

## Available locales

The application is currently using the Rails default [`Backend::Simple`](https://github.com/svenfuchs/i18n/blob/master/lib/i18n/backend/simple.rb) to store the translations and the 
available locales.

In order to add/remove available locales from the application, you must modify the config entry for `config.i18n.available_locales` in the `config/application.rb` or the appropriate `config/environments/*.rb` file if
you want to test a specific locale on a staging server.

This should be the default. However, anywhere within the request lifecycle, you can modify the `I18n.available_locales` method. This may be useful if you are testing features for specific users (maybe using [flipper](https://github.com/jnunemaker/flipper)), etc.

Currently, the `config.i18n.enforce_available_locales` is set to `false`. If set to `true`, then the application will throw a `I18n::InvalidLocale` if the system tries to set a locale that is not available within `I18n.available_locales`. If this value is `false` then the default locale will be used. This seems like the best setting.

## Specifying the locale

By default, the language should be determined by the header (HTTP_ACCEPT_LANGUAGE)
The user can change the language in the footer, which will add a subdomain (es.bikeindex.org) or path (bikeindex.org/es)

The default language (english) will have no sub domain or path specified

## Looking up translations

## Localized views

Localized views are views that have a locale extension (e.g. `home/welcome.es.html.erb`) and they are rendered when if that locale is the current locale (in this case, `:es`).
These should be used when the view has a lot of static content and it would be cumbersome to specify all of the content in YAML files.

More information can be found in the [Rails Guides](http://guides.rubyonrails.org/i18n.html#localized-views).

## JavaScript/CoffeeScript

## Naming conventions

### Including HTML

## Testing

### Testing localized views

It is a good idea to test that you have the appropriate [localized views](#localized-views) and that they are rendering correctly.

You can test these within `ActionController` tests. The only way that I have found to test these is to ensure that the rendered body contains some sort of the localized language. To test the rendered body you have to ensure that you use the `render_views` option within the context of the test. You can then set the `I18n.locale` before you call the controller action and assert the response.

Here is an example:

```rb
describe HomeController do
  #...
  describe :welcome do
    context 'for english speakers' do
      before { get :welcome }
      it { should render_template :welcome }
    end

    context 'for spanish speakers' do
      render_views
      before do
        I18n.locale = :es
        get :welcome
      end

      it 'renders the spanish localized template' do
        expect(response.body).to match /Holla/im
      end
    end
  end
  #...
end
```

## Retrieving translations

TODO:
------

- [ ] create and test localized views
- [ ] create a valid `info/serials.es.html.erb (already tested)
