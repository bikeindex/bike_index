class FlavorText < ActiveRecord::Base
  def self.old_attr_accessible
    %w(message).map(&:to_sym).freeze
  end
  
  validates_presence_of :message

end
