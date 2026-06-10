require "rails_helper"

# TEMPORARY: intentional failures to preview the consolidated "Test results"
# CI summary (full backtraces). Remove this file once we've seen the output.
RSpec.describe "Temporary CI failure demo" do
  it "fails an expectation" do
    expect(1 + 1).to eq(3)
  end

  it "raises an error" do
    raise "boom from temp ci failure demo"
  end

  it "fails a different expectation" do
    expect("hello").to include("goodbye")
  end
end
