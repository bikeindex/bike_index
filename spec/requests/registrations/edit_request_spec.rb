require "rails_helper"

RSpec.describe "RegistrationsController#edit", type: :request do
  it "redirects to the bike edit page, preserving query params" do
    get "/registrations/42/edit"
    expect(response).to redirect_to("/bikes/42/edit")

    get "/registrations/42/edit?view_as=brakebills.staff"
    expect(response).to redirect_to("/bikes/42/edit?view_as=brakebills.staff")
  end
end
