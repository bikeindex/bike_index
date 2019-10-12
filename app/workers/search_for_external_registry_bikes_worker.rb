class SearchForExternalRegistryBikesWorker < ApplicationWorker
  def perform(serial_number)
    client = ExternalRegistryClient::VerlorenOfGevondenClient.new
    client.search(serial_number)
  end
end
