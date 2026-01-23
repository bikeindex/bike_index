require "rails_helper"

base_url = "/sales"
RSpec.describe SalesController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:item) { FactoryBot.create(:bike, :with_primary_activity, :with_ownership_claimed, user:) }
  let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale, item:) }
  let(:marketplace_message) { FactoryBot.create(:marketplace_message, marketplace_listing:) }
  let(:ownership) { item.current_ownership }
  let(:current_user) { user }

  describe "new" do
    context "with a marketplace_message_id" do
      it "renders" do
        expect(marketplace_message.id).to be_present
        expect(item.reload.authorized?(current_user)).to be_truthy
        get "#{base_url}/new?marketplace_message_id=#{marketplace_message.id}"
        expect(response).to render_template(:new)
        expect(flash).to be_blank
        expect(assigns(:sale)).to be_present
      end
      context "turbo_stream request" do
        it "renders turbo_stream" do
          expect(marketplace_message.id).to be_present
          get "#{base_url}/new?marketplace_message_id=#{marketplace_message.id}",
            headers: {"Accept" => "text/vnd.turbo-stream.html"}
          expect(response.media_type).to eq Mime[:turbo_stream]
          expect(response.body).to include("mark_sold_section")
          expect(assigns(:sale)).to be_present
        end
      end
      context "not user's marketplace_message" do
        let(:current_user) { marketplace_message.sender }
        it "redirects" do
          expect(item.reload.authorized?(current_user)).to be_falsey
          get "#{base_url}/new?marketplace_message_id=#{marketplace_message.id}"
          expect(response).to redirect_to(my_account_path)
          expect(flash[:error]).to be_present
        end
      end
      context "bike has already been transferred" do
        let(:new_ownership) do
          BikeServices::OwnershipTransferer.find_or_create(item, updator: user,
            new_owner_email: "someone-else@example.com")
        end
        it "renders" do
          expect(marketplace_message.id).to be_present
          expect(item.reload.authorized?(current_user)).to be_truthy
          get "#{base_url}/new?marketplace_message_id=#{marketplace_message.id}"
          expect(response).to render_template(:new)
          expect(flash).to be_blank
          expect(assigns(:sale)).to be_present
        end
      end
    end
    context "with an existing sale record" do
      # TODO: improve handling of this (and create)
      it "redirects"
    end

    context "without a current_user" do
      let(:current_user) { nil }
      it "redirects" do
        get "#{base_url}/new?ownership_id=#{ownership.id}"
        expect(response).to redirect_to(:new_session)
        expect(flash[:error].match(/log in/i)).to be_present
      end
      context "without a found ownership" do
        it "redirects" do
          get "#{base_url}/new?ownership_id=3333333"
          expect(flash[:error].match(/log in/i)).to be_present
        end
      end
    end
  end

  describe "create" do
    context "with marketplace_message" do
      let(:sale_params) do
        {
          amount: 123.69,
          currency: "USD",
          marketplace_message_id: marketplace_message.id,
          ownership_id: ownership.id
        }
      end
      let(:target_attrs) do
        {
          amount_cents: 12369,
          currency_enum: "usd",
          ownership_id: ownership.id,
          marketplace_message_id: marketplace_message.id,
          seller_id: user.id,
          sold_via: "bike_index_marketplace",
          item_id: item.id,
          item_type: "Bike",
          sold_at: Time.current

        }
      end
      let(:new_ownership_attrs) do
        {
          bike_id: item.id,
          user_id: marketplace_message.sender_id
        }
      end
      before { expect(marketplace_message).to be_present }

      def expect_created_sale(target_sale_attrs:, ownership_change: 1)
        expect do
          post "/sales", params: {sale: sale_params}
          expect(response).to redirect_to my_account_path
          expect(flash[:success]).to be_present
        end.to change(Sale, :count).by(1)
          .and change(CallbackJob::AfterSaleCreateJob.jobs, :count).by 1

        expect { CallbackJob::AfterSaleCreateJob.drain }
          .to change(Ownership, :count).by ownership_change

        expect(Sale.count).to eq 1
        sale = Sale.last
        expect(sale).to match_hash_indifferently target_attrs
        expect(sale.sold_at).to be_within(2).of Time.current
        expect(sale.new_ownership).to match_hash_indifferently new_ownership_attrs
        expect(sale.buyer&.id).to eq marketplace_message.sender_id

        expect(item.reload.is_for_sale).to be_falsey
        expect(item.current_ownership_id).to eq sale.new_ownership.id
      end

      it "creates a sale" do
        expect(item.reload.is_for_sale).to be_truthy

        expect_created_sale(target_sale_attrs: target_attrs)
      end

      context "not bike owner" do
        let(:current_user) { FactoryBot.create(:user_confirmed) }
        it "doesn't create a sale" do
          expect(ownership)
          expect(item.reload.is_for_sale).to be_truthy
          expect do
            post base_url, params: {sale: sale_params}
            expect(response).to redirect_to my_account_path
            expect(flash[:error]).to match(/permission to sell/i)
          end.to change(Sale, :count).by(0)
        end
      end

      context "bike has already transferred" do
        let(:new_owner_email) { marketplace_message.sender.email }
        let(:new_ownership) do
          BikeServices::OwnershipTransferer.find_or_create(item, updator: user, new_owner_email:)
        end
        it "creates a sale" do
          expect(ownership).to be_present
          expect(new_ownership.id).to_not eq ownership.id
          expect(item.reload.is_for_sale).to be_falsey

          expect_created_sale(target_sale_attrs: target_attrs, ownership_change: 0)
        end
      end
    end
  end
end
