# Spec helpers that are included in all request specs
# via Rspec.configure (rails_helper)
module RequestSpecHelpers
  attr_reader :current_user, :current_organization

  def log_in(user = nil)
    user ||= FactoryBot.create(:user_confirmed)
    @current_user = user
    allow(User).to receive(:from_auth) { user }
  end

  RSpec.shared_context :request_spec_logged_in_as_superuser do
    let(:user) { FactoryBot.create(:admin) }
    before { log_in(user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_organization_admin do
    let(:user) { FactoryBot.create(:organization_admin) }
    let(:organization) { user.organizations.first }
    before { log_in(user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_organization_member do
    let(:user) { FactoryBot.create(:organization_member) }
    let(:organization) { user.organizations.first }
    before { log_in(user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_ambassador do
    let(:user) { FactoryBot.create(:ambassador) }
    let(:organization) { user.organizations.first }
    before { log_in(user) }
  end
end
