require "rails_helper"

RSpec.describe "RegistrationsController#edit", type: :request do
  it "redirects to the bike edit page" do
    get "/registrations/42/edit"
    expect(response).to redirect_to("/bikes/42/edit")
  end
end
