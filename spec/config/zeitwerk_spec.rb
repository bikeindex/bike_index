require "rails_helper"

RSpec.describe "Zeitwerk" do
  it "Successfully eager loads all files" do
    expect do
      Zeitwerk::Loader.eager_load_all
    end.not_to raise_error
  end
end
