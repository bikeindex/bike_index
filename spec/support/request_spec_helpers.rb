# Spec helpers that are included in all request specs
# via Rspec.configure (rails_helper)
module RequestSpecHelpers
  attr_reader :current_user, :current_organization

  def log_in(user = nil)
    user ||= FactoryBot.create(:user_confirmed)
    @current_user ||= user
    allow(User).to receive(:from_auth) { user }
  end

  def log_in_as_superuser
    user = FactoryBot.create(:admin)
    log_in user
  end

  def log_in_as_organization_admin
    user = FactoryBot.create(:organization_admin)
    @current_organization ||= user.organizations.first
    log_in user
  end

  def log_in_as_organization_member
    user = FactoryBot.create(:organization_memebr)
    @current_organization ||= user.organizations.first
    log_in user
  end

  def log_in_as_ambassador
    user = FactoryBot.create(:ambassador)
    @current_organization ||= user.organizations.first
    log_in user
  end
end
