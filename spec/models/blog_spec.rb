require 'spec_helper'

describe Blog do
  
  # describe :validations do 
  #   it { should validate_presence_of :title }
  #   it { should validate_presence_of :body }
  #   it { should validate_presence_of :user_id }
  #   it { should validate_uniqueness_of :title }
  #   it { should validate_uniqueness_of :title_slug }
  # end

  describe :set_created_date do 
    it "should make the title 50 char long and character safe for params" do
      @user = FactoryGirl.create(:user)
      blog = Blog.new(title: "A really really really really loooooooooooooooooooooooooooooooooooong title that absolutely rocks so hard", body: "some things", user_id: @user.id, post_date: Time.now)
      blog.save
      blog.title_slug.should eq("a-really-really-really-really-looooooooooooooooooo")
    end
  end
  describe :create_abbreviation do 
    it "should make the text 200 char long or less and remove any new lines" do 
      @user = FactoryGirl.create(:user)
      blog = Blog.new(title: "Blog title", user_id: @user.id, post_date: Time.now )
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
      blog.body_abbr.should eq("Lorem ipsum dolor sit amet! Consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ...")
    end

    it "should remove any link information and images" do 
      # TODO: remove markdown images
      # Also, it would be cool if we could end on a word instead of in the middle of one...
      @user = FactoryGirl.create(:user)
      blog = Blog.new(title: "Blog title", user_id: @user.id, post_date: Time.now )
      blog.body = """
      View the link
      [here](http://something)
      ![PBR, a bike bag and drawings](http://imgur.com/e4zzEjP.jpg)
      """
      blog.save
      blog.body_abbr.should eq("View the link here")
    end
  end
end
