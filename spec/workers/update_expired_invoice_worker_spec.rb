require "spec_helper"

describe UpdateExpiredInvoiceWorker, type: :lib do
  let(:subject) { UpdateExpiredInvoiceWorker }
  let(:instance) { subject.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(subject.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(subject.frequency).to be > 11.hours
  end

  describe "perform" do
    let(:invoice_active) { FactoryBot.create(:invoice_paid) }
    let(:invoice_active_updated_at) { Time.now - 1.day }
    let(:organization1) { invoice_active.organization }
    let(:invoice_expired) { FactoryBot.create(:invoice_paid, start_at: Time.now - 2.weeks) }
    let(:organization2) { invoice_expired.organization }
    it "schedules all the workers" do
      invoice_active.update_column :updated_at, invoice_active_updated_at
      # TODO: Rails 5 update - after commit. Also done below below
      organization1.update_attributes(updated_at: Time.now)
      organization2.update_attributes(updated_at: Time.now)
      invoice_active.reload
      expect(invoice_active.updated_at).to be_within(1.second).of invoice_active_updated_at
      expect(organization1.is_paid).to be_truthy
      expect(organization1.current_invoice.paid_in_full?).to be_truthy
      # Manually make invoice expired
      invoice_expired.update_column :subscription_end_at, Time.now - 1.day
      invoice_expired.reload
      expect(invoice_expired.should_expire?).to be_truthy
      expect(invoice_expired.active?).to be_truthy
      expect(invoice_expired.expired?).to be_truthy
      # expired invoice is still active for the organization
      expect(organization2.is_paid).to be_truthy
      expect(organization2.current_invoice.paid_in_full?).to be_truthy
      expect(organization2.current_invoice.active?).to be_truthy
      instance.perform
      # TODO: Rails 5 update - after commit.
      organization1.reload
      organization2.reload
      organization1.update_attributes(updated_at: Time.now)
      organization2.update_attributes(updated_at: Time.now)
      invoice_active.reload
      invoice_expired.reload
      expect(organization1.is_paid).to be_truthy
      expect(organization1.current_invoice.paid_in_full?).to be_truthy
      # the active invoice updated_at hasn't been bumped
      expect(invoice_active.updated_at).to be_within(1.second).of invoice_active_updated_at
      # And expired invoice has been updated
      expect(invoice_expired.active?).to be_falsey
      expect(invoice_expired.expired?).to be_truthy
      expect(organization2.is_paid).to be_falsey
      expect(organization2.current_invoice).to_not be_present
    end
  end
end
