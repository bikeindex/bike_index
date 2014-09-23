# Internationalization

## Storing the translations

## Specifying the locale

By default, the language should be determined by the header (HTTP_ACCEPT_LANGUAGE)
The user can change the language in the footer, which will add a subdomain (es.bikeindex.org) or path (bikeindex.org/es)

The default language (english) will have no sub domain or path specified

## Looking up translations

## Locale file hierarchy

```
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

## Naming conventions

### Including HTML

## Testing

## Retrieving translations
