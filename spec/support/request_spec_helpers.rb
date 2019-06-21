# Spec helpers that are included in all request specs
# via Rspec.configure (rails_helper)
module RequestSpecHelpers
  attr_reader :current_user, :current_organization

  def log_in(user = nil)
    user ||= FactoryBot.create(:user_confirmed)
    @current_user = user
    allow(User).to receive(:from_auth) { user }
  end

  RSpec.shared_context :request_spec_logged_in_as_user do
    let(:user) { FactoryBot.create(:user) }
    before { log_in(user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_superuser do
    let(:user) { FactoryBot.create(:admin) }
    before { log_in(user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_organization_admin do
    let(:organization) { FactoryBot.create(:organization) }
    let(:user) { FactoryBot.create(:organization_admin, organization: organization) }
    before { log_in(user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_organization_member do
    let(:organization) { FactoryBot.create(:organization) }
    let(:user) { FactoryBot.create(:organization_member, organization: organization) }
    before { log_in(user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_ambassador do
    let(:organization) { FactoryBot.create(:organization_ambassador) }
    let(:user) { FactoryBot.create(:ambassador, organization: organization) }
    before { log_in(user) }
  end
end
