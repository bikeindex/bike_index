RSpec.shared_context :with_paper_trail do
  before { PaperTrail.enabled = true }

  after { PaperTrail::Version.delete_all }
end
