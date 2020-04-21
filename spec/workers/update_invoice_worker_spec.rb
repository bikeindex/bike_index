require "rails_helper"

RSpec.describe UpdateInvoiceWorker, type: :job do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 11.hours
  end

  describe "perform" do
    let(:invoice_active) { FactoryBot.create(:invoice_paid) }
    let(:invoice_active_updated_at) { Time.current - 1.day }
    let(:organization1) { invoice_active.organization }
    let(:invoice_expired) { FactoryBot.create(:invoice_paid, start_at: Time.current - 2.weeks) }
    let(:organization2) { invoice_expired.organization }
    let!(:invoice_to_activate)  { FactoryBot.create(:invoice_paid, start_at: Time.current + 0.5) }
    let(:organization3) { invoice_to_activate.organization }
    it "schedules all the workers" do
      expect(invoice_to_activate.future?).to be_truthy
      invoice_active.update_column :updated_at, invoice_active_updated_at
      organization1.save
      organization2.save
      expect(organization3.is_paid).to be_falsey

      expect(invoice_active.updated_at).to be_within(1.second).of invoice_active_updated_at
      expect(organization1.is_paid).to be_truthy
      expect(organization1.current_invoices.first.paid_in_full?).to be_truthy
      # Manually make invoice expired
      invoice_expired.update_column :subscription_end_at, Time.current - 1.day
      invoice_expired.reload
      expect(invoice_expired.should_expire?).to be_truthy
      expect(invoice_expired.active?).to be_truthy
      expect(invoice_expired.expired?).to be_truthy
      # expired invoice is still active for the organization
      expect(organization2.is_paid).to be_truthy
      expect(organization2.current_invoices.first.paid_in_full?).to be_truthy
      expect(organization2.current_invoices.first.active?).to be_truthy
      sleep 0.5 # Ensure time has passed to make invoice_to_activate no longer future
      expect(invoice_to_activate.future?).to be_falsey
      described_class.new.perform

      organization1.save
      organization2.save
      invoice_active.reload
      invoice_expired.reload

      expect(organization1.is_paid).to be_truthy
      expect(organization1.current_invoices.first.paid_in_full?).to be_truthy
      # the active invoice updated_at hasn't been bumped
      expect(invoice_active.updated_at).to be_within(1.second).of invoice_active_updated_at
      # And expired invoice has been updated
      expect(invoice_expired.active?).to be_falsey
      expect(invoice_expired.expired?).to be_truthy
      expect(organization2.is_paid).to be_falsey
      expect(organization2.current_invoices.first).to_not be_present

      invoice_to_activate.reload
      expect(invoice_to_activate.active?).to be_truthy
      expect(organization3.is_paid).to be_truthy
    end
  end
end
