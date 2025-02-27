require "rails_helper"

RSpec.describe ListicleImageSizeJob, type: :job do
  it "enqueues another awesome job" do
    ListicleImageSizeJob.perform_async
    expect(ListicleImageSizeJob).to have_enqueued_sidekiq_job
  end
end
