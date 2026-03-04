# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Strava scheduled jobs" do
  let(:scheduled_jobs) { ScheduledJobRunner.scheduled_jobs }

  it "includes ScheduledRequestEnqueuer with expected frequency and queue" do
    expect(scheduled_jobs).to include(StravaJobs::ScheduledRequestEnqueuer)
    expect(StravaJobs::ScheduledRequestEnqueuer.frequency).to eq 59
    expect(StravaJobs::ScheduledRequestEnqueuer.sidekiq_options["queue"]).to eq "low_priority"
  end

  it "includes ScheduledRequestPriorityUpdator with expected frequency and queue" do
    expect(scheduled_jobs).to include(StravaJobs::ScheduledRequestPriorityUpdator)
    expect(StravaJobs::ScheduledRequestPriorityUpdator.frequency).to eq 50.minutes
    expect(StravaJobs::ScheduledRequestPriorityUpdator.sidekiq_options["queue"]).to eq "low_priority"
  end
end
