RSpec.configure do |config|
  config.before { PaperTrail.enabled = false }
end
