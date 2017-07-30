require 'spec_helper'

describe ImageAssociatorWorker do
  it { is_expected.to be_processed_in :updates }

  it 'enqueues another awesome job' do
    ImageAssociatorWorker.perform_async
    expect(ImageAssociatorWorker).to have_enqueued_sidekiq_job
  end
end
