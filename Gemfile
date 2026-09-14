source "https://rubygems.org"

gemspec

gem 'abbrev', '~> 0.1.2'

group :development do
  gem 'rspec', '~> 3.12'
  gem 'rake', '~> 13.0'
  gem 'rubocop-rake'
  gem 'simplecov', '~> 0.22.0'
end

# Audits the locked gems against the Ruby Advisory Database:
#   bundle exec bundle-audit check --update
gem 'bundler-audit', require: false, groups: %i[development test]
