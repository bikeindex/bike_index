require "rails_helper"

RSpec.describe MyAccounts::MessagesController, type: :request do
  base_url = "/my_account/messages"

  describe "index" do
    context "user not logged in" do
      it "redirects" do
        get base_url
        expect(response).to redirect_to(/session\/new/) # weird subdomain issue matching url directly otherwise
        expect(session[:return_to]).to eq "/my_account/messages"
      end
    end

    context "user logged in" do
      include_context :request_spec_logged_in_as_user

      context "unconfirmed" do
        let(:current_user) { FactoryBot.create(:user) }
        it "redirects" do
          expect(current_user.confirmed?).to be_falsey
          get base_url
          expect(flash).to_not be_present
          expect(response).to redirect_to(please_confirm_email_users_path)
        end
      end

      context "confirmed" do
        let(:current_user) { FactoryBot.create(:user_confirmed) }

        it "renders" do
          expect(current_user.confirmed?).to be_truthy
          # Even though any_for_user is false
          expect(MarketplaceMessage.any_for_user?(current_user)).to be_falsey
          get base_url
          expect(response.status).to eq(200)
          expect(response).to render_template("index")
        end
      end
    end
  end

  describe "show" do
    let(:status) { :for_sale }
    let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :with_address_record, status:) }
    let(:show_url) { "#{base_url}/ml_#{marketplace_listing.id}" }

    it "redirects" do
      get show_url
      expect(response).to redirect_to(/session\/new/) # weird subdomain issue matching url directly otherwise
      expect(session[:return_to]).to eq show_url
    end

    context "logged in" do
      include_context :request_spec_logged_in_as_user

      it "renders" do
        expect(marketplace_listing.visible_by?(current_user)).to be_truthy
        get show_url
        expect(response.status).to eq(200)
        expect(response).to render_template("show")
        expect(assigns(:marketplace_listing)&.id).to eq(marketplace_listing.id)
        expect(assigns(:can_send_message)).to be_truthy
      end

      context "current_user: seller" do
        let(:current_user) { marketplace_listing.seller }
        it "404s" do
          get show_url
          expect(response.status).to eq(404)
        end

        context "with existing marketplace_message" do
          let!(:marketplace_message) { FactoryBot.create(:marketplace_message, marketplace_listing:) }
          it "renders" do
            expect(marketplace_message.reload.receiver_id).to eq current_user.id
            get show_url
            expect(response.status).to eq(404)

            get "#{base_url}/#{marketplace_message.id}"
            expect(response.status).to eq(200)
            expect(response).to render_template("show")
            expect(assigns(:marketplace_listing)&.id).to eq(marketplace_listing.id)
            expect(assigns(:can_send_message)).to be_truthy
          end

          context "marketplace_listing status: removed" do
            let(:status) { :removed }
            it "renders" do
              expect(marketplace_message.reload.receiver_id).to eq current_user.id
              get show_url
              expect(response.status).to eq(404)

              get "#{base_url}/#{marketplace_message.id}"
              expect(response.status).to eq(200)
              expect(response).to render_template("show")
              expect(assigns(:marketplace_listing)&.id).to eq(marketplace_listing.id)
              expect(assigns(:can_send_message)).to be_truthy
            end
          end
        end
      end

      context "marketplace_listing status: draft" do
        let(:status) { :draft }

        it "404s" do
          expect(marketplace_listing.visible_by?(current_user)).to be_falsey
          get show_url
          expect(response.status).to eq(404)
        end
      end

      context "marketplace_listing status: sold" do
        let(:status) { :sold }

        it "doesn't render" do
          can_see_message = MarketplaceMessage.can_see_messages?(user: current_user, marketplace_listing:)
          expect(can_see_message).to be_falsey
          get show_url
          expect(response.status).to eq(404)
        end

        context "marketplace_message is a reply" do
          let!(:marketplace_message) { FactoryBot.create(:marketplace_message, marketplace_listing:, sender: current_user) }

          it "renders" do
            get show_url
            expect(response.status).to eq(200)
            expect(response).to render_template("show")
            expect(assigns(:marketplace_messages)&.pluck(:id)).to eq([marketplace_message.id])
            expect(assigns(:can_send_message)).to be_truthy
          end
        end
      end

      context "marketplace_listing status: removed" do
        let(:status) { :removed }

        it "doesn't render" do
          can_see_message = MarketplaceMessage.can_see_messages?(user: current_user, marketplace_listing:)
          expect(can_see_message).to be_falsey
          get show_url
          expect(response.status).to eq(404)
        end

        context "marketplace_message is a reply" do
          let!(:marketplace_message) { FactoryBot.create(:marketplace_message, marketplace_listing:, sender: current_user) }

          it "renders" do
            get show_url
            expect(response.status).to eq(200)
            expect(response).to render_template("show")
            expect(assigns(:marketplace_messages)&.pluck(:id)).to eq([marketplace_message.id])
            expect(assigns(:can_send_message)).to be_truthy
          end
        end
      end
    end
  end

  describe "create" do
    include_context :request_spec_logged_in_as_user

    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :with_address_record, status:) }
    let(:status) { :for_sale }
    let(:new_params) do
      {
        initial_record_id: "",
        marketplace_listing_id: marketplace_listing.id,
        subject: "something something",
        body: "Mumble Mumble Mumble, bikes, etc"
      }
    end

    it "sends a message and a reply" do
      expect(marketplace_listing).to be_present
      ActionMailer::Base.deliveries = []
      expect do
        post base_url, params: {marketplace_message: new_params}
        expect(response.status).to eq(302)
        expect(flash[:success]).to be_present
      end.to change(MarketplaceMessage, :count).by 1

      marketplace_message = MarketplaceMessage.last
      expect(marketplace_message).to match_hash_indifferently(new_params.except(:initial_record_id))
      expect(marketplace_message.sender_id).to eq current_user.id
      expect(marketplace_message.receiver_id).to eq marketplace_listing.seller_id
      expect(Email::MarketplaceMessageJob.jobs.count).to eq 1
      Email::MarketplaceMessageJob.drain
      expect(ActionMailer::Base.deliveries.count).to eq 1

      follow_up_params = new_params.merge(initial_record_id: marketplace_message.id, body: "More thanks")
      Sidekiq::Testing.inline! do
        expect do
          post base_url, params: {marketplace_message: follow_up_params}
          expect(flash[:success]).to be_present
        end.to change(MarketplaceMessage, :count).by(1)
          .and change(ActionMailer::Base.deliveries, :count).by 1
      end

      expect(MarketplaceMessage.last).to match_hash_indifferently({initial_record_id: marketplace_message.id,
        sender_id: current_user.id, receiver_id: marketplace_listing.seller_id, body: follow_up_params[:body],
        subject: "Re: #{new_params[:subject]}", marketplace_listing_id: marketplace_listing.id})

      # Sending repeats doesn't create duplicates
      Sidekiq::Testing.inline! do
        expect do
          post base_url, params: {marketplace_message: follow_up_params}
          post base_url, params: {marketplace_message: follow_up_params}
          post base_url, params: {marketplace_message: follow_up_params}
        end.to change(MarketplaceMessage, :count).by 0
      end
    end

    context "invalid post" do
      it "renders with errors" do
        expect do
          post base_url, params: {marketplace_message: new_params.except(:body)}
          expect(response.status).to eq(200)
        end.to change(MarketplaceMessage, :count).by 0

        expect(flash).to be_blank
        expect(response).to render_template("show")
        expect(assigns(:marketplace_listing)&.id).to eq marketplace_listing.id

        assigned_errors = assigns(:marketplace_message).errors.full_messages
        expect(assigned_errors).to eq(["Body can't be blank"])
        expect(response.body).to match(ERB::Util.html_escape(assigned_errors.first))
      end
    end

    context "not user's marketplace_message" do
      let!(:marketplace_message) { FactoryBot.create(:marketplace_message, marketplace_listing:) }

      it "404s" do
        expect(marketplace_message.user_ids).to_not include(current_user.id)
        can_see_message = MarketplaceMessage.can_see_messages?(user: current_user, marketplace_listing:, marketplace_message:)
        expect(can_see_message).to be_falsey

        expect do
          post base_url, params: {
            marketplace_message: new_params.merge(initial_record_id: marketplace_message.id)
          }
        end.to change(MarketplaceMessage, :count).by 0
        expect(response.status).to eq(404)
      end
    end

    context "seller reply" do
      let(:current_user) { marketplace_listing.seller }
      let!(:marketplace_message) { FactoryBot.create(:marketplace_message, marketplace_listing:) }
      let(:reply_params) { new_params.merge(initial_record_id: marketplace_message.id.to_s) }

      it "sends a message" do
        ActionMailer::Base.deliveries = []

        Sidekiq::Testing.inline! do
          expect do
            post base_url, params: {marketplace_message: reply_params}
            expect(flash[:success]).to be_present
          end.to change(MarketplaceMessage, :count).by 1
        end

        new_marketplace_message = MarketplaceMessage.last
        expect(new_marketplace_message).to match_hash_indifferently(reply_params.except(:subject))
        expect(new_marketplace_message.subject).to eq "Re: #{marketplace_message.subject}"
        expect(new_marketplace_message.sender_id).to eq current_user.id
        expect(new_marketplace_message.receiver_id).to eq marketplace_message.sender_id

        expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      end
    end
  end
end
