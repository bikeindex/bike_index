require "rails_helper"

RSpec.describe "my_account", type: :routing do
  describe "show" do
    it "directs to my_account" do
      expect(get: "my_account").to route_to(controller: "my_accounts", action: "show")
    end
  end

  describe "update" do
    it "directs to my_account" do
      expect(patch: "my_account").to route_to(controller: "my_accounts", action: "update")
    end
  end

  describe "destroy" do
    it "directs to my_account" do
      expect(delete: "my_account").to route_to(controller: "my_accounts", action: "destroy")
    end
  end

  describe "edit" do
    it "directs to root" do
      expect(get: "/my_account/edit").to route_to(
        controller: "my_accounts", action: "edit"
      )
    end
    context "root" do
      it "sends root to root" do
        expect(get: "/my_account/edit/root").to route_to(
          controller: "my_accounts", action: "edit", edit_template: "root"
        )
      end
    end
    context "password" do
      it "sends password to password" do
        expect(get: "/my_account/edit/password").to route_to(
          controller: "my_accounts", action: "edit", edit_template: "password"
        )
      end
    end
    context "unknown template" do
      it "sends surprise_template to surprise_template" do
        expect(get: "/my_account/edit/surprise_template").to route_to(
          controller: "my_accounts", action: "edit", edit_template: "surprise_template"
        )
      end
    end
  end

  describe "messages" do
    describe "index" do
      it "directs to my_account" do
        expect(get: "my_account/messages").to route_to(
          controller: "my_account/messages", action: "index"
        )
      end
    end

    describe "new" do
      it "directs to my_account" do
        expect(get: "my_account/messages/new").to route_to(
          controller: "my_account/messages", action: "new"
        )
      end
    end
  end
end
