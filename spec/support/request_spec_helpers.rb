# Spec helpers that are included in all request specs
# via Rspec.configure (rails_helper)
module RequestSpecHelpers
  # Lame copy of user_root_url - required because of subdomain: false
  def user_root_url
    return my_account_url if current_user&.confirmed?

    root_url
  end

  def log_in(current_user = nil)
    return if current_user == false # Allow skipping log in by setting current_user: false

    current_user ||= FactoryBot.create(:user_confirmed)
    allow(User).to receive(:from_auth) { current_user }
  end

  RSpec.shared_context :request_spec_logged_in_as_user do
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    before { log_in(current_user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_user_if_present do
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    before { log_in(current_user) if current_user.present? }
  end

  RSpec.shared_context :request_spec_logged_in_as_superuser do
    let(:current_user) { FactoryBot.create(:superuser) }
    before { log_in(current_user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_developer do
    let(:current_user) { FactoryBot.create(:developer) }
    before { log_in(current_user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_organization_admin do
    let(:current_organization) { FactoryBot.create(:organization) }
    let(:current_user) { FactoryBot.create(:organization_admin, organization: current_organization) }
    before { log_in(current_user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_organization_user do
    let(:current_organization) { FactoryBot.create(:organization) }
    let(:current_user) { FactoryBot.create(:organization_user, organization: current_organization) }
    before { log_in(current_user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_ambassador do
    let(:current_organization) { FactoryBot.create(:organization_ambassador) }
    let(:current_user) { FactoryBot.create(:ambassador, organization: current_organization) }
    before { log_in(current_user) }
  end
end
