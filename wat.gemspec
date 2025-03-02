# frozen_string_literal: true

require_relative "lib/wat/version"

Gem::Specification.new do |spec|
  spec.name = "wat"
  spec.version = Wat::VERSION
  spec.authors = ["watministrator"]
  spec.email = ["john@shields.wtf"]

  spec.summary = "A pure, strongly typed Lisp implemented in Ruby"
  spec.description = "Wat is a minimal, expert-friendly Lisp with static typing and no IO, built for functional purity."
  spec.homepage = "https://github.com/watmin/wat"
  spec.license = "WTFPL"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/watmin/wat"
  spec.metadata["changelog_uri"] = "https://github.com/watmin/wat"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  spec.add_development_dependency "pry", "~> 0.15"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "reline", "~> 0.6"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.21"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
