require "rails_helper"

RSpec.describe ImageAssociatorJob, type: :job do
  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "high_priority"
  end
end
