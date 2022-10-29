require File.expand_path('lib/enc-drive-backup/version', __dir__)

Gem::Specification.new do |s|
  s.name        = 'enc-drive-backup'
  s.version     = EncDriveBackup::VERSION
  s.homepage    = 'https://gitlab.fit.cvut.cz/ancinpet/ruby/tree/master/semestral'
  s.license     = 'MIT'
  s.author      = 'Petr Ančinec'
  s.email       = 'ancinpet@fit.cvut.cz'

  s.summary     = 'Tool for secure storage on Google Drive.'

  s.files       = Dir['bin/*', 'spec/*', 'lib/**/*', '*.gemspec', 'LICENSE*', 'README*']
  s.executables = Dir['bin/*'].map { |f| File.basename(f) }
  s.has_rdoc    = 'yard'

  s.required_ruby_version = '>= 2.4'

  s.add_runtime_dependency 'archive-zip', '~> 0.12.0'
  s.add_runtime_dependency 'google-api-client', '~> 0.34'
  s.add_runtime_dependency 'rubyzip', '~> 2.3.0'
  s.add_runtime_dependency 'thor', '~> 0.20.0'

  s.add_development_dependency 'rake', '~> 12.0'
  s.add_development_dependency 'rspec', '~> 3.6'
  s.add_development_dependency 'yard', '~> 0.9'
end
