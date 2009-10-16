require "rake"

Gem::Specification.new do |s|
   s.name = %q{attachment_on_the_fly}
   s.version = "0.1"
   s.date = %q{2009-10-16}
   s.authors = ["Jeff Sutherland"]
   s.email = %q{jefferey.sutherland@gmail.com}
   s.summary = %q{A Paperclip mix-in to allow auto-generation of resized images}
   s.homepage = %q{http://www.pentodelabs.com/}
   s.description = %q{}
   s.files = FileList['lib/**/*','README','Rakefile'].to_a
end
