# BinxUtils

Utility classes extracted from the Bike Index Rails application for time parsing, timezone handling, input normalization, and RSpec matchers.

## Installation

Add to your Gemfile:

```ruby
gem "binx_utils", path: "gems/binx_utils"
```

## Usage

### TimeParser

Parses time strings with flexible format support and timezone handling.

```ruby
# Basic parsing
BinxUtils::TimeParser.parse("2024-01-15 10:30:00")
BinxUtils::TimeParser.parse("2024-01-15 10:30:00", "America/Los_Angeles")

# Parse with timezone preservation
BinxUtils::TimeParser.parse("2024-01-15T10:30:00-05:00", in_time_zone: true)

# Parse timestamps
BinxUtils::TimeParser.parse(1705312200)

# Parse year only (returns Jan 1 of that year)
BinxUtils::TimeParser.parse("2024")

# Check if a value looks like a timestamp
BinxUtils::TimeParser.looks_like_timestamp?(1705312200)  # => true
BinxUtils::TimeParser.looks_like_timestamp?("1705312200") # => true

# Round time to nearest hour
BinxUtils::TimeParser.round(Time.current)

# Set default timezone (used when no timezone specified)
BinxUtils::TimeParser.default_time_zone = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
```

Supported formats:
- ISO 8601: `2024-01-15T10:30:00-05:00`
- Date and time: `2024-01-15 10:30:00`
- Unix timestamps: `1705312200`
- Year only: `2024`
- Month/year: `2024-03`, `03/2024`
- US date format: `01/15/2024`
- Paychex format: `01/15/2024 10:30 AM`

### TimeZoneParser

Parses timezone strings and extracts timezone information from time strings.

```ruby
# Parse timezone by name
BinxUtils::TimeZoneParser.parse("America/Los_Angeles")
BinxUtils::TimeZoneParser.parse("Pacific Time (US & Canada)")
BinxUtils::TimeZoneParser.parse("America/New York")  # handles spaces

# Extract timezone from a time string with offset
BinxUtils::TimeZoneParser.parse_from_time_string("2024-01-15T10:30:00-05:00")
# => #<ActiveSupport::TimeZone name="Eastern Time (US & Canada)">

# Parse from time and offset
BinxUtils::TimeZoneParser.parse_from_time_and_offset(
  time: Time.current,
  offset: -21600  # or "-06:00"
)

# Get the full timezone name
tz = BinxUtils::TimeZoneParser.parse("America/Los_Angeles")
BinxUtils::TimeZoneParser.full_name(tz)
# => "Pacific Time (US & Canada)"
```

### InputNormalizer

Sanitizes and normalizes user input.

```ruby
# Parse boolean values
BinxUtils::InputNormalizer.boolean("1")      # => true
BinxUtils::InputNormalizer.boolean("true")   # => true
BinxUtils::InputNormalizer.boolean("false")  # => false
BinxUtils::InputNormalizer.boolean(nil)      # => false

# Normalize strings (strip and collapse whitespace)
BinxUtils::InputNormalizer.string("  hello   world  ")  # => "hello world"
BinxUtils::InputNormalizer.string(nil)                   # => nil

# Check if value is present or explicitly false
BinxUtils::InputNormalizer.present_or_false?(false)  # => true
BinxUtils::InputNormalizer.present_or_false?(nil)    # => false

# Sanitize HTML input
BinxUtils::InputNormalizer.sanitize("<script>alert('xss')</script>Hello")
# => "Hello"
BinxUtils::InputNormalizer.sanitize("Bike & Ski")  # => "Bike & Ski"

# Escape for regex matching
BinxUtils::InputNormalizer.regex_escape("foo.bar")  # => "foo.bar"
```

## RSpec Matchers

The gem includes RSpec matchers for testing. Require them in your `spec_helper.rb`:

```ruby
require "binx_utils"
Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }
```

Or require the gem's support files directly:

```ruby
require "binx_utils"
require "path/to/gems/binx_utils/spec/support/hash_matcher"
require "path/to/gems/binx_utils/spec/support/match_time_matcher"
```

### match_time

Compares times within a precision tolerance (default: 0.0001 seconds).

```ruby
expect(actual_time).to match_time(expected_time)
expect(actual_time).to match_time(expected_time, 1.second)
expect(actual_time).to match_time(expected_time, 5.minutes)
```

### match_hash_indifferently

Compares hashes with flexible matching rules:

```ruby
expect(actual_hash).to match_hash_indifferently(expected_hash)
```

Features:
- String/symbol key indifference
- Time comparison within 1 second tolerance
- Numeric type flexibility (`12 == 12.0 == "12"`)
- Array order independence
- Boolean coercion (`"1" == true`, `"" == false`)
- Blank value equivalence (`nil == ""`)
- Nested hash support
- ActiveRecord object attribute matching

```ruby
# These all match:
expect({foo: 12}).to match_hash_indifferently({"foo" => 12.0})
expect({time: Time.current}).to match_hash_indifferently({time: Time.current + 0.5})
expect({items: [1, 2, 3]}).to match_hash_indifferently({items: [3, 1, 2]})
expect({active: true}).to match_hash_indifferently({active: "1"})
```

## Dependencies

- `activesupport` >= 7.0
- `rails-html-sanitizer` >= 1.0

## License

MIT
