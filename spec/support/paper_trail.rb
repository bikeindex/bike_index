RSpec.shared_context :with_paper_trail do
  before { PaperTrail.enabled = true }
  after { PaperTrailVersion.delete_all }
end
