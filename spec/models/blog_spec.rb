require 'spec_helper'

describe Blog do  
  # describe 'validations' do
  #   it { should validate_presence_of :title }
  #   it { should validate_presence_of :body }
  #   it { should validate_presence_of :user_id }
  #   it { should validate_uniqueness_of :title }
  #   it { should validate_uniqueness_of :title_slug }
  # end

  describe 'set_title_slug' do
    it "makes the title 70 char long and character safe for params" do
      @user = FactoryGirl.create(:user)
      blog = Blog.new(title: "A really really really really loooooooooooooooooooooooooooooooooooong title that absolutely rocks so hard", body: "some things", user_id: @user.id, published_at: Time.now)
      blog.save
      expect(blog.title_slug).to eq("a-really-really-really-really-loooooooooooooooooooooooooooooooooooong")
    end
  end

  describe 'update_title_save' do
    it "makes the title 70 char long and character safe for params" do
      @user = FactoryGirl.create(:user)
      blog = Blog.new(title: "A really really really really loooooooooooooooooooooooooooooooooooong title that absolutely rocks so hard", body: "some things", user_id: @user.id, published_at: Time.now)
      blog.save
      blog.title = "New Title"
      blog.update_title = '1'
      blog.save
      expect(blog.title_slug).to eq('new-title')
      expect(blog.old_title_slug).to eq("a-really-really-really-really-loooooooooooooooooooooooooooooooooooong")
    end
  end


  describe 'create_abbreviation' do
    it "makes the text 200 char long or less and remove any new lines" do
      @user = FactoryGirl.create(:user)
      blog = Blog.new(title: "Blog title", user_id: @user.id, published_at: Time.now )
      blog.body = """
      Lorem ipsum dolor sit amet! Consectetur adipisicing elit, sed do eiusmod


      tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,

      quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo

      consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse
      cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non
      
      proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
      lorem  
      """
      blog.save
      expect(blog.body_abbr).to eq("Lorem ipsum dolor sit amet! Consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ...")
    end

    it "creates the body abbr from a listicle" do
      @user = FactoryGirl.create(:user)
      blog = Blog.create(title: "Blog title", user_id: @user.id, published_at: Time.now, body: "stuff", is_listicle: true)
      Listicle.create(blog_id: blog.id, body: "View the link\n[here](http://something)\n\n<img class='post-image' src='https://files.bikeindex.org/uploads/Pu/1003/large_photo__6_.JPG' alt='Bike Index shirt and stickers'>\n![PBR, a bike bag and drawings](http://imgur.com/e4zzEjP.jpg) and also this")
      blog.reload.save
      expect(blog.reload.body_abbr).to eq("View the link here and also this")
    end

    it "removes any link information and images" do
      # TODO: remove markdown images
      # Also, it would be cool if we could end on a word instead of in the middle of one...
      @user = FactoryGirl.create(:user)
      blog = Blog.new(title: "Blog title", user_id: @user.id, published_at: Time.now )
      blog.body = "View the link\n[here](http://something)\n\n<img class='post-image' src='https://files.bikeindex.org/uploads/Pu/1003/large_photo__6_.JPG' alt='Bike Index shirt and stickers'>\n![PBR, a bike bag and drawings](http://imgur.com/e4zzEjP.jpg) and also this"
      blog.save
      expect(blog.body_abbr).to eq("View the link here and also this")
    end
  end

  describe 'set_index_image' do
    it "sets the public image for a blog" do
      blog = FactoryGirl.create(:blog)
      public_image = FactoryGirl.create(:public_image, imageable: blog)
      blog.reload # Reload so it knows about association
      blog.set_index_image
      expect(blog.index_image_id).to eq(public_image.id)
    end

    it "doesn't break if image doesn't exist" do
      blog = FactoryGirl.create(:blog)
      public_image = FactoryGirl.create(:public_image, imageable: blog)
      blog.reload # Reload so it knows about association
      blog.index_image_id = 3399
      blog.set_index_image
      expect(blog.index_image_id).to eq(public_image.id)
    end

    it "has before_save_callback_method defined for set_index_image" do
      expect(Blog._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_index_image)).to eq(true)
    end
  end

  describe 'feed_content' do
    it "returns html content for non-listicles" do
      blog = Blog.new(body: 'something')
      expect(blog.feed_content).to eq("<p>something</p>\n")
    end

    it 'returns listicles' do
      blog = Blog.new(is_listicle: true)
      listicle = Listicle.new(body: "body", title: 'title', image_credits: 'credit')
      listicle.htmlize_content
      allow(blog).to receive(:listicles).and_return([listicle])
      target = '<article><div class="listicle-image-credit"><p>credit</p>' + 
        "\n" + '</div><h2 class="list-item-title">title</h2></article><article><p>body</p>' +
        "\n" + '</article>'
      expect(blog.feed_content).to eq(target)
    end
  end
end
