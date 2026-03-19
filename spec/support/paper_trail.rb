RSpec.shared_context :with_paper_trail do
  around do |example|
    PaperTrail.enabled = true
    example.run
  ensure
    PaperTrail.enabled = false
    PaperTrailVersion.delete_all
  end
end
