source 'https://rubygems.org'

# Specify your gem's dependencies in manticore.gemspec
gemspec

group :development, :test do
  # NOTE: should eventually become a runtime dependency
  gem "base64", require: false

  gem "rake-compiler", require: false
  gem "simplecov", require: false

  gem "rspec", "~> 3.0"
  gem "rspec-its"

  gem "rack", ">= 2.1.4", require: false
  gem "json", require: false
  gem "webrick", require: false
  gem "net-http-server", require: false
  gem "gserver", require: false
end
