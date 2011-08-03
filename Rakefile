require 'rubygems'
require 'rake'
require 'yaml'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "lda-ruby"
    gem.summary = %Q{Ruby port of Latent Dirichlet Allocation by David M. Blei.}
    gem.description = %Q{Ruby port of Latent Dirichlet Allocation by David M. Blei. See http://www.cs.princeton.edu/~blei/lda-c/.}
    gem.email = "jasonmadams@gmail.com"
    gem.homepage = "http://github.com/ealdent/lda-ruby"
    gem.authors = ['David Blei', 'Jason Adams', 'Rio Akasaka']
    gem.extensions = ['ext/lda-ruby/extconf.rb']
    gem.files.include 'stopwords.txt'
    gem.require_paths = ['lib', 'ext']
    gem.add_dependency 'shoulda'
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end

rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/*_test.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION.yml')
    config = YAML.load(File.read('VERSION.yml'))
    version = "#{config[:major]}.#{config[:minor]}.#{config[:patch]}"
  else
    version = ""
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "lda-ruby #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

