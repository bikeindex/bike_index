class CreateVersionJob < ApplicationJob
  sidekiq_options retry: 1, queue: "med_priority"

  def perform(attributes)
    PaperTrail::Version.create!(attributes)
  end
end
