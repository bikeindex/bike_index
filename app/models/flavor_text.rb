class FlavorText < ActiveRecord::Base
  def self.old_attr_accessible
    %w(message)
  end
  
  validates_presence_of :message

end
