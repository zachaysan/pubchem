# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pubchem/version'

Gem::Specification.new do |spec|
  spec.name          = "pubchem"
  spec.version       = Pubchem::VERSION
  spec.authors       = ["Zach Aysan"]
  spec.email         = ["zachaysan@gmail.com"]

  spec.summary = %q{ Collect Pubchem substance and compound data }
  spec.description = %q{ While there is a great FTP mirror for
                         molecule data, it is hard to deal with 
                         their form. This helps with that!} 
  spec.homepage = "https://github.com/zachaysan/pubchem"
  spec.license = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "mechanize"

  spec.add_development_dependency "bundler", "~> 1.10"

end
