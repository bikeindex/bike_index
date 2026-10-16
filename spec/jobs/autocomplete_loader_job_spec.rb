require "rails_helper"

RSpec.describe AutocompleteLoaderJob, type: :job do
  it "calls AutocompleteLoaderJob", :flaky do
    expect(Autocomplete::Loader).to receive(:clear_redis)
    expect(Autocomplete::Loader).to receive(:load_all)
    AutocompleteLoaderJob.new.perform("clear")
  end

  describe "enqueue_reload" do
    before do
      Sidekiq::Job.clear_all
      RedisPool.conn { |r| r.del(AutocompleteLoaderJob::PENDING_KEY) }
    end

    it "enqueues one reload until it runs" do
      3.times { AutocompleteLoaderJob.enqueue_reload }
      expect(AutocompleteLoaderJob.jobs.count).to eq 1

      AutocompleteLoaderJob.new.perform
      AutocompleteLoaderJob.enqueue_reload
      expect(AutocompleteLoaderJob.jobs.count).to eq 2
    end
  end
end
