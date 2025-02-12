require "rails_helper"

RSpec.describe SearchForExternalRegistryBikesWorker, type: :job do
  describe "#perform" do
    it "enqueues an external registry search" do
      query = 2722
      client = ExternalRegistryClient::VerlorenOfGevondenClient.new
      allow(client).to receive(:search).with(2722)
      allow(ExternalRegistryClient::VerlorenOfGevondenClient).to receive(:new).and_return(client)

      expect { described_class.perform_async(query) }
        .to(change { described_class.jobs.count }.by(1))

      Sidekiq::Worker.drain_all
      expect(client).to have_received(:search).once
    end
  end
end
