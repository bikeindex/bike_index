require "rails_helper"

RSpec.describe ListicleImageSizeWorker do
  it "enqueues another awesome job" do
    ListicleImageSizeWorker.perform_async
    expect(ListicleImageSizeWorker).to have_enqueued_sidekiq_job
  end
end
