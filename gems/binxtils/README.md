# Binxtils

Bike Index utility modules, extracted as a gem.

## Modules

- **Binxtils::InputNormalizer** - Sanitize and normalize user input strings
- **Binxtils::TimeParser** - Parse fuzzy time/date strings into `Time` objects
- **Binxtils::TimeZoneParser** - Parse and resolve time zone strings

## Usage

All modules use [Functionable](https://github.com/sethherr/functionable) and are called as class methods:

```ruby
Binxtils::TimeParser.parse("next thursday")
Binxtils::InputNormalizer.string("  Some Input  ")
Binxtils::TimeZoneParser.parse("Eastern Time")
```
