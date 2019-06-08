require "database_cleaner"

# DB Cleaner metadata tags
# ========================
#
# Use the following RSpec metadata tags to tweak how the database is reset
# between tests.
#
# * `strategy: :transaction` (default)
#
# Fastest. Performs queries in a transaction and rolls back at the end of the
# test. A sensible default. The tag can be omitted.
#
# * `strategy: :deletion`
#
# Slower, but comparable in speed to :transaction for small data sets.
# Useful for testing `after_commit` callbacks.
# Does not re-create tables or indexes.
#
# * `strategy: :truncation`
#
# Slowest. Fixed-time regardless of the amount of data (hence cost-effective
# only for large or complicated data setups). Runtime grows with the number of
# tables, indexes, complexity of the db overall.
#
# * `:context_state`
#
# To skip example-wise cleaning (e.g., to share large setup between examples).
# Use sparingly.
#
# ```
# before(:all) { ... }
#
# describe "test 1", :context_state do ...
#
# describe "test 2", :context_state do ...
# ```
#
# * `:js`
#
# For acceptance / system tests (Capybara/Cucumber/Rails 5 system tests) with a
# JS driver. Enables the truncation strategy, which is slowest but most stable.
#

class DirtyDatabaseError < RuntimeError
  def initialize(meta)
    super "#{meta[:full_description]}\n\t#{meta[:location]}"
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:deletion)
  end

  config.before(:all, :context_state) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.start
  end

  config.before(:each) do |example|
    next if example.metadata[:context_state]

    strategy =
      example.metadata[:strategy] ||
      (example.metadata[:js] ? :truncation : :transaction)

    DatabaseCleaner.strategy = strategy
    DatabaseCleaner.start
  end

  config.after(:each) do |example|
    next if example.metadata[:context_state]

    DatabaseCleaner.clean

    # For debugging:
    # if ModelName.count > 0
    #   raise DirtyDatabaseError.new(example.metadata)
    # end
  end

  config.after(:all, :context_state) do
    DatabaseCleaner.clean
  end
end
