source 'https://rubygems.org'

ruby '3.2.2'

gem 'sinatra', '~>1.4.7'
gem 'sinatra-contrib'
gem 'erubis'
gem 'pg'
gem 'bcrypt'
group :test do
  gem 'minitest-hooks'
end
group :development, :test do
  gem "webrick", "~>1.8.1"
end
group :production do
  gem "puma", "~>6.2.1"
end