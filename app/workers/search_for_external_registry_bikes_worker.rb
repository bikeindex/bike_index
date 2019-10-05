class SearchForExternalRegistryBikesWorker < ApplicationWorker
  def perform(serial_number)
    client = ExternalRegistry::VerlorenOfGevondenClient.new
    client.search(serial_number)
  end
end
