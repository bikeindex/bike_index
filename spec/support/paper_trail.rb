RSpec.shared_context :with_paper_trail do
  before do
    PaperTrail.enabled = true
    Sidekiq::Testing.inline!
  end

  after do
    Sidekiq::Testing.fake!
    PaperTrail::Version.delete_all
  end
end
