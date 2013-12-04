require 'rubygems'
require 'rspec'

class Hash
  def symbolize_keys!
    keys.each do |key|
      self[(key.to_sym rescue key) || key] = delete(key)
    end
    self
  end
end

class Paperclip
  def self.options
    {}
  end
  def self.log msg
  end
  class Attachment
    def initialize
    end
    def path
      "/path.png"
    end
    def url
      "/url"
    end
    def original_filename
      "/file.png"
    end
  end
end

require_relative '../lib/attachment_on_the_fly'
