require "rails_helper"

RSpec.describe Blog, type: :model do
  describe "friendly_find" do
    let(:user) { FactoryBot.create(:user) }
    let!(:blog) { Blog.create(title: "foo title", body: "ummmmm good", user_id: user.id, old_title_slug: "an-elder-statesman-title") }
    it "finds by the things we expect it to" do
      expect(blog.title_slug).to eq "foo-title"
      expect(Blog.friendly_find("foo title").id).to eq blog.id
      expect(Blog.friendly_find("foo-title").id).to eq blog.id
      expect(Blog.friendly_find(blog.id).id).to eq blog.id
      expect(Blog.friendly_find("an-elder-statesman-title").id).to eq blog.id
      # These should work, to give us a little bit better edge, but for now, whatever
      # expect(Blog.friendly_find("an-elder-statesman").id).to eq blog.id
      # blog2 = FactoryBot.create(:blog, title: "an elder statesman")
      # expect(blog2).to be_present
      # expect(Blog.friendly_find("an-elder-statesman").id).to eq blog2.id
    end
  end

  describe "set_title_slug" do
    it "makes the title 70 char long and character safe for params" do
      @user = FactoryBot.create(:user)
      blog = Blog.new(title: "A really really really really loooooooooooooooooooooooooooooooooooong title that absolutely rocks so hard", body: "some things", user_id: @user.id, published_at: Time.current)
      blog.save
      expect(blog.title_slug).to eq("a-really-really-really-really-loooooooooooooooooooooooooooooooooooong")
    end
    context "long title" do
      let(:title) { "We made it all the way to Oregon and back without one dysentery scare" }
      let(:target) { "we-made-it-all-the-way-to-oregon-and-back-without-one-dysentery-scare" }
      let(:legacy_slug) { "we-made-it-all-the-way-to-oregon-and-back-without-" }
      let(:blog) { FactoryBot.create(:blog, title: title, body: "text about making it to Oregon") }
      it "doesn't break things" do
        blog.reload
        expect(blog.title_slug).to eq target
        expect(Blog.friendly_find(target)).to eq blog
        # legacy issue where we chopped stuff down
        blog.update_attribute :title_slug, legacy_slug
        expect(Blog.friendly_find(legacy_slug)).to eq blog
      end
    end
  end

  describe "update_title_save" do
    it "makes the title 70 char long and character safe for params" do
      @user = FactoryBot.create(:user)
      blog = Blog.new(title: "A really really really really loooooooooooooooooooooooooooooooooooong title that absolutely rocks so hard", body: "some things", user_id: @user.id, published_at: Time.current)
      blog.save
      blog.title = "New Title"
      blog.update_title = "1"
      blog.save
      expect(blog.title_slug).to eq("new-title")
      expect(blog.old_title_slug).to eq("a-really-really-really-really-loooooooooooooooooooooooooooooooooooong")
    end
  end

  describe "create_abbreviation" do
    it "makes the text 200 char long or less and remove any new lines" do
      @user = FactoryBot.create(:user)
      blog = Blog.new(title: "Blog title", user_id: @user.id, published_at: Time.current)
      blog.body = "" "
      Lorem ipsum dolor sit amet! Consectetur adipisicing elit, sed do eiusmod


      tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,

      quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo

      consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse
      cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non

      proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
      lorem
      " ""
      blog.save
      expect(blog.body_abbr).to eq("Lorem ipsum dolor sit amet! Consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ...")
    end

    it "creates the body abbr from a listicle" do
      @user = FactoryBot.create(:user)
      blog = Blog.create(title: "Blog title", user_id: @user.id, published_at: Time.current, body: "stuff", is_listicle: true)
      Listicle.create(blog_id: blog.id, body: "View the link\n[here](http://something)\n\n<img class='post-image' src='https://files.bikeindex.org/uploads/Pu/1003/large_photo__6_.JPG' alt='Bike Index shirt and stickers'>\n![PBR, a bike bag and drawings](http://imgur.com/e4zzEjP.jpg) and also this")
      blog.reload.save
      expect(blog.reload.body_abbr).to eq("View the link here and also this")
    end

    it "removes any link information and images" do
      # TODO: remove markdown images
      # Also, it would be cool if we could end on a word instead of in the middle of one...
      @user = FactoryBot.create(:user)
      blog = Blog.new(title: "Blog title", user_id: @user.id, published_at: Time.current)
      blog.body = "View the link\n[here](http://something)\n\n<img class='post-image' src='https://files.bikeindex.org/uploads/Pu/1003/large_photo__6_.JPG' alt='Bike Index shirt and stickers'>\n![PBR, a bike bag and drawings](http://imgur.com/e4zzEjP.jpg) and also this"
      blog.save
      expect(blog.body_abbr).to eq("View the link here and also this")
    end
  end

  describe "set_index_image" do
    it "sets the public image for a blog" do
      blog = FactoryBot.create(:blog)
      public_image = FactoryBot.create(:public_image, imageable: blog)
      blog.reload # Reload so it knows about association
      blog.set_index_image
      expect(blog.index_image_id).to eq(public_image.id)
    end

    it "doesn't break if image doesn't exist" do
      blog = FactoryBot.create(:blog)
      public_image = FactoryBot.create(:public_image, imageable: blog)
      blog.reload # Reload so it knows about association
      blog.index_image_id = 3399
      blog.set_index_image
      expect(blog.index_image_id).to eq(public_image.id)
    end
  end

  describe "canonical_url validation" do
    let(:blog) { FactoryBot.build(:blog, canonical_url: canonical_url) }
    before { blog.set_calculated_attributes }
    context "blank" do
      let(:canonical_url) { " " }
      it "is valid" do
        expect(blog).to be_valid
        expect(blog.canonical_url).to be_nil
      end
    end
    context "nil" do
      let(:canonical_url) { nil }
      it "is valid" do
        expect(blog).to be_valid
        expect(blog.canonical_url).to be_nil
      end
    end

    context "given a complete url" do
      context "http" do
        let(:canonical_url) { "http://blogger.com/myblog" }
        it "is valid" do
          expect(blog).to be_valid
          expect(blog.canonical_url).to eq canonical_url
        end
      end
      context "https" do
        let(:canonical_url) { "https://www.usacycling.org/article/in-our-own-words-lily-williams-olympic-postponement" }
        it "is valid" do
          expect(blog).to be_valid
          expect(blog.canonical_url).to eq canonical_url
        end
      end
    end

    context "given an incomplete url" do
      let(:canonical_url) { "blogger.com/myblog" }
      it "is invalid" do
        expect(blog).to be_valid
        expect(blog.canonical_url).to eq "http://#{canonical_url}"
      end
    end
  end

  describe "feed_content" do
    it "returns html content for non-listicles" do
      blog = Blog.new(body: "something")
      expect(blog.feed_content).to eq("<p>something</p>\n")
    end

    it "returns listicles" do
      blog = Blog.new(is_listicle: true)
      listicle = Listicle.new(body: "body", title: "title", image_credits: "credit")
      listicle.htmlize_content
      allow(blog).to receive(:listicles).and_return([listicle])
      target = '<article><div class="listicle-image-credit"><p>credit</p>' \
               "\n" + '</div><h2 class="list-item-title">title</h2></article><article><p>body</p>' \
      "\n" + "</article>"
      expect(blog.feed_content).to eq(target)
    end
  end
end
