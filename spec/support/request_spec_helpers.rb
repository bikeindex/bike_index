# Spec helpers that are included in all request specs
# via Rspec.configure (rails_helper)
module RequestSpecHelpers
  def log_in(current_user = nil)
    current_user ||= FactoryBot.create(:user_confirmed)
    allow(User).to receive(:from_auth) { current_user }
  end

  RSpec.shared_context :request_spec_logged_in_as_user do
    let(:current_user) { FactoryBot.create(:user) }
    before { log_in(current_user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_superuser do
    let(:current_user) { FactoryBot.create(:admin) }
    before { log_in(current_user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_organization_admin do
    let(:current_organization) { FactoryBot.create(:organization) }
    let(:current_user) { FactoryBot.create(:organization_admin, organization: current_organization) }
    before { log_in(current_user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_organization_member do
    let(:current_organization) { FactoryBot.create(:organization) }
    let(:current_user) { FactoryBot.create(:organization_member, organization: current_organization) }
    before { log_in(current_user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_ambassador do
    let(:current_organization) { FactoryBot.create(:organization_ambassador) }
    let(:current_user) { FactoryBot.create(:ambassador, organization: current_organization) }
    before { log_in(current_user) }
  end
end
