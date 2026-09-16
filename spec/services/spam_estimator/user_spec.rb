require "rails_helper"

RSpec.describe SpamEstimator::User do
  def spam_matches(user)
    SpamEstimator::Text.seo_spam_matches(described_class.scannable_text(user))
  end

  describe "estimate" do
    let(:user) { User.new(show_bikes: true, name:, description:) }
    let(:name) { "Rider Person" }
    let(:description) { "I ride bikes around Chicago and love my Surly." }

    it "is low for an ordinary profile" do
      expect(described_class.estimate(user)).to be < SpamEstimator::User::MARK_SPAM_PERCENT
    end

    it "is 0 for a blank user" do
      expect(described_class.estimate(nil)).to eq 0
      expect(described_class.estimate(User.new)).to eq 0
    end

    context "crypto/gambling references" do
      # links are regex-scanned but not scored as text, so the score is exactly 30 per reference
      let(:user) { User.new(show_bikes: true, my_bikes_hash: {"link_target" => link_target}) }

      context "a single reference" do
        let(:link_target) { "https://buy-bitcoin.example" }
        it "adds 30 on top of the link's 50, staying below the threshold" do
          expect(described_class.estimate(user)).to eq 80
        end
      end

      context "several references" do
        let(:link_target) { "https://bitcoin-ethereum-casino-poker.example" }
        it "adds 30 each, clamped to 100" do
          expect(described_class.estimate(user)).to eq 100
        end
      end
    end

    context "Indonesian gambling profile" do
      let(:name) { "LGO234" }
      let(:description) { "LGO234 merupakan situs resmi slot gacor ternama, terpercaya dan gampang menang" }

      it "is above the spam threshold" do
        expect(described_class.estimate(user)).to be > SpamEstimator::User::MARK_SPAM_PERCENT
      end
    end

    context "Vietnamese gambling profile" do
      let(:name) { "MU99" }
      let(:description) { "Mu99 là link truy cập nhà cái Mu88, cá cược trực tuyến uy tín" }

      it "is above the spam threshold" do
        expect(described_class.estimate(user)).to be > SpamEstimator::User::MARK_SPAM_PERCENT
      end
    end

    context "gift-card balance-check profile" do
      let(:name) { "McGift Giftcardmall" }
      let(:description) do
        "This platform offers a secure way to access gift card services. Whether conducting " \
          "mcgift.giftcardmall balance inquiries or completing mcgiftcard activation, every " \
          "step is directed through a verified pathway to official encrypted servers."
      end

      it "is above the spam threshold" do
        expect(described_class.estimate(user)).to be > SpamEstimator::User::MARK_SPAM_PERCENT
      end
    end

    context "gift-card brand run together in a username" do
      # these profiles smash the brand into usernames and domains, so the gift-card
      # terms deliberately aren't \b-anchored the way the crypto/gambling ones are
      let(:user) do
        User.new(show_bikes: true, username: "vanillaprepaid6",
          my_bikes_hash: {"link_target" => "https://vanilla-prepaid.cc/"})
      end

      it "counts references inside the run-together string" do
        expect(described_class.estimate(user)).to be > SpamEstimator::User::MARK_SPAM_PERCENT
      end
    end

    context "prepaid outside a gift-card context" do
      # the profiles this caught — prepaid funerals, travel SIMs, mobile recharge — are
      # link-only profiles with no registrations, so the bare term stays unqualified
      it "counts as a reference" do
        ["Pre-arranged and prepaid funeral options across Adelaide.",
          "Prepaid travel SIM cards and eSIMs, so you stay connected overseas."]
          .each do |description|
            expect(spam_matches(User.new(show_bikes: true, description:)))
              .to eq({"prepaid" => 1})
          end
      end
    end

    context "a shop that sells gift cards" do
      # one reference is 30 on top of the link's 50 — it takes a second to reach the
      # threshold, which is what separates a real shop from a link farm
      let(:description) { "Community bike shop. We do tune-ups, wheel builds and fittings. Gift cards available in store." }
      let(:user) do
        User.new(show_bikes: true, name:, description:, my_bikes_hash: {"link_target" => "https://shop.example"})
      end

      it "stays below the threshold" do
        expect(spam_matches(user).values.sum).to eq 1
        expect(described_class.estimate(user)).to be < SpamEstimator::User::MARK_SPAM_PERCENT
      end
    end

    context "online pharmacy profile" do
      let(:user) do
        User.new(show_bikes: true, username: "pills4cure", title: "Pills4Cure",
          description: "An online pharmacy offering medications for pain relief, erectile dysfunction and more.",
          my_bikes_hash: {"link_target" => "https://www.pills4cure.com/"})
      end

      it "is above the spam threshold" do
        expect(spam_matches(user)).to eq({"pills" => 3, "pharmacy" => 1, "medications" => 1, "erectile dysfunction" => 1})
        expect(described_class.estimate(user)).to be > SpamEstimator::User::MARK_SPAM_PERCENT
      end
    end

    context "generic medical words" do
      let(:description) { "Sports medicine clinic. We manage medication and fit prescription glasses. Fish oil 1000mg." }

      it "counts them as references" do
        expect(spam_matches(user))
          .to eq({"medicine" => 1, "medication" => 1, "prescription" => 1, "1000mg" => 1})
      end

      context "an MG Road address" do
        let(:description) { "Visit us at 123 MG Road, Bengaluru, or 45 MG Rd" }

        it "is not a dosage" do
          expect(spam_matches(user)).to eq({})
        end
      end
    end

    context "bike brands that share a drug's name" do
      it "counts them only after a buying verb" do
        expect(spam_matches(User.new(show_bikes: true, description: "I ride a Soma Wolverine and a Norco Search")))
          .to eq({})
        expect(spam_matches(User.new(show_bikes: true, description: "Buy Soma online, order Norco")))
          .to eq({"buy soma" => 1, "order norco" => 1})
      end
    end

    context "real names that contain spam terms as substrings" do
      # usernames are auto-generated random strings, so substring matching would ban real people
      it "does not count them as references" do
        %w[Judith Hagen Sloth Donohue Totonchy Sexton Bolanos].each do |real_name|
          expect(described_class.estimate(User.new(show_bikes: true, name: real_name, description:)))
            .to be < SpamEstimator::User::MARK_SPAM_PERCENT
        end
      end
    end

    context "gibberish description" do
      let(:description) { "efgBz9pNdd7efgBz9pNdd7 xzkqwrmlbnptvxz" }
      it "is above the spam threshold" do
        expect(described_class.estimate(user)).to be > SpamEstimator::User::MARK_SPAM_PERCENT
      end
    end

    context "gibberish only in name/username (weighted lightly)" do
      let(:user) { User.new(show_bikes: true, name: "VhriBJhD1nuwHoI9", username: "efgBz9pNdd7efgBz9", description:) }
      it "stays below the threshold" do
        expect(described_class.estimate(user)).to be < SpamEstimator::User::MARK_SPAM_PERCENT
      end
    end

    context "scannable_text" do
      let(:user) { User.new(show_bikes: true, title: "Nhà cái uy tín", twitter: "casinovip") }

      it "includes the link fields and handles" do
        expect(described_class.scannable_text(user)).to eq "Nhà cái uy tín casinovip"
        expect(described_class.scannable_text(nil)).to eq ""
        expect(described_class.scannable_text(User.new)).to eq ""
      end
    end

    context "promotional link" do
      let(:user) { User.new(show_bikes: true, my_bikes_hash: {"link_target" => link_target}) }
      let(:link_target) { "https://my-bike-blog.example" }

      it "adds 50, staying below the threshold on its own" do
        expect(described_class.estimate(user)).to eq 50
      end

      it "adds nothing without a link" do
        expect(described_class.estimate(User.new(show_bikes: true))).to eq 0
      end
    end

    context "user owns bikes" do
      # one reference plus the link keeps the base under the clamp, so the reduction is observable
      let(:user) do
        FactoryBot.create(:user_confirmed, show_bikes: true, name:, username: "riderperson", description:,
          my_bikes_hash: {"link_target" => "https://bitcoin.example"})
      end

      it "subtracts 40 for one bike and 80 for two" do
        base = described_class.estimate(user)
        expect(base).to be < 100 # otherwise the clamp hides the reduction
        FactoryBot.create(:bike, :with_ownership_claimed, user:)
        expect(described_class.estimate(user.reload)).to eq(base - 40)
        FactoryBot.create(:bike, :with_ownership_claimed, user:)
        expect(described_class.estimate(user.reload)).to eq(base - 80)
      end

      it "ignores likely_spam bikes, so a junk registration earns no reduction" do
        base = described_class.estimate(user)
        bike = FactoryBot.create(:bike, :with_ownership_claimed, user:)
        expect(described_class.estimate(user.reload)).to eq(base - 40)
        bike.update(likely_spam: true)
        expect(described_class.estimate(user.reload)).to eq base
      end
    end
  end
end
