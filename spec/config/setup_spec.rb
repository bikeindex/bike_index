# frozen_string_literal: true

require "rails_helper"
require "open3"

# bin/setup runs in a subprocess, so it creates records outside the test
# transaction. Use deletion strategy to clean up after.
RSpec.describe "bin/setup" do
  it "runs successfully" do
    output = nil
    status = nil
    Dir.chdir(Rails.root) do
      output, status = Open3.capture2e({"RAILS_ENV" => "test"}, "bin/setup")
    end
    expect(status).to be_success, "bin/setup failed with:\n#{output}"
  ensure
    DatabaseCleaner.clean_with(:deletion)
  end
end
