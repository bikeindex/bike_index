require "spec_helper"

describe Admin::PaymentsController, type: :controller do
  let(:subject) { FactoryGirl.create(:payment) }
  let(:organization) { FactoryGirl.create(:organization) }
  include_context :logged_in_as_super_admin
  let(:params) { { organization_id: 10000, email: user2.email, amount_cents: 22_222 } }

  describe "index" do
    it "renders" do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe "edit" do
    it "renders" do
      get :edit, id: subject.to_param
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
    end
  end

  describe "new" do
    it "renders" do
      get :new
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
    end
  end

  describe "update" do
    context "stripe payment" do
      it "updates available attributes" do
        put :update, id: subject.to_param, payment: params
        subject.reload
        expect(subject.organization).to eq organization
        expect(subject.user).to eq user # Not changed for stripe payments
        expect(subject.amount_cents).to_not eq 22_222 # Not changed
      end
    end
    context "check payment" do
      let(:subject) { FactoryGirl.create(:payment_check, organization: nil, amount_cents: 55_555, user: user) }
      it "updates available attributes" do
        put :update, id: subject.to_param, payment: params
        subject.reload
        expect(subject.organization).to eq organization
        expect(subject.user).to be_nil
        expect(subject.email).to eq "cool@party.com"
        expect(subject.amount_cents).to eq 55555 # Not changed
      end
    end
  end

  describe "create" do
    let(:user2) { FactoryGirl.create(:user) }
    context "stripe payment" do
      it "does not create" do
        expect do
          post :create, payment: params.merge(kind: "stripe")
        end.to_not change(Payment, :count)
      end
    end
    context "check payment" do
      it "creates" do
        expect do
          post :create, payment: params.merge(kind: "check")
        end.to change(Payment, :count).by 1
        payment = Payment.last
        expect(payment.organization).to eq organization
        expect(payment.user).to eq user2
        expect(payment.email).to eq user2.email
        expect(payment.amount_cents).to eq 22_222
        expect(payment.kind).to eq "check"
      end
    end
  end
end