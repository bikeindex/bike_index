require "rails_helper"

RSpec.describe "users routing", type: :routing do
  describe "my_account" do
    it "renders show" do
      expect(get: "/my_account").to route_to(
        controller: "my_accounts",
        action: "show"
      )
    end
  end

  describe "edit" do
    it "directs to edit" do
      expect(get: "/my_account/edit").to route_to(
        controller: "my_accounts",
        action: "edit"
      )
    end
    context "edit_template parameter" do
      it "directs to edit" do
        expect(get: "/my_account/edit/password").to route_to(
          controller: "my_accounts",
          action: "edit",
          edit_template: "password"
        )
      end
      it "directs to edit" do
        expect(get: "/my_account/edit?edit_template=sharing").to route_to(
          controller: "my_accounts",
          action: "edit",
          edit_template: "sharing"
        )
      end
    end
  end
end
