require "rails_helper"

RSpec.describe EmailAdminContactStolenWorker, type: :job do
  describe "perform" do
    it "sends an email" do
      stolen_bike = FactoryBot.create(:stolen_bike)
      FactoryBot.create(:ownership, bike: stolen_bike)
      customer_contact = FactoryBot.create(:customer_contact, bike: stolen_bike)
      ActionMailer::Base.deliveries = []
      EmailAdminContactStolenWorker.new.perform(customer_contact.id)
      expect(ActionMailer::Base.deliveries).not_to be_empty
    end
  end
end
