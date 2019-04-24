require "spec_helper"

describe ImageAssociatorWorker do
  let(:subject) { ImageAssociatorWorker }

  it "is the correct queue" do
    expect(subject.sidekiq_options["queue"]).to eq "high_priority"
  end

  it "enqueues another awesome job" do
    ImageAssociatorWorker.perform_async
    expect(ImageAssociatorWorker).to have_enqueued_sidekiq_job
  end
end
