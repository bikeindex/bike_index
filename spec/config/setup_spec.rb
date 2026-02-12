# frozen_string_literal: true

require "rails_helper"
require "open3"

RSpec.describe "bin/setup" do
  it "runs successfully" do
    output = nil
    status = nil
    Dir.chdir(Rails.root) do
      output, status = Open3.capture2e("bin/setup")
    end
    expect(status).to be_success, "bin/setup failed with:\n#{output}"
  end
end
