#!/usr/bin/env ruby

require 'bundler/setup'
require 'sinatra'
require 'oauth2'
require 'base64'
require 'json'

$stdout.sync = true # docker IO buffer

oauth = OAuth2::Client.new(
  ENV["OAUTH_CLIENT_ID"],
  ENV["OAUTH_CLIENT_SECRET"],
  authorize_url: "https://www.fitbit.com/oauth2/authorize",
  token_url: "https://api.fitbit.com/oauth2/token"
)

token_path = "./shared/token.yml"

if File.exist? token_path
  token_hash = YAML.load File.read(token_path)
  token = OAuth2::AccessToken.from_hash(oauth, token_hash)
else
  token = nil
end

get '/' do
  if token
    "<a href='/sleep/#{(Date.today - 1).iso8601}'>Get yesterday's sleep data</a>"
  else
    "<a href='/authorize'>Authorize</a>"
  end
end

get '/authorize' do
  redirect oauth.auth_code.authorize_url(scope: "sleep")
end

get '/callback' do
  basic = Base64.encode64("#{ENV["OAUTH_CLIENT_ID"]}:#{ENV["OAUTH_CLIENT_SECRET"]}")
  token = oauth.auth_code.get_token(
    params[:code],
    headers: {
      "Authorization": "Basic #{basic}"
    }
  )
  File.open(token_path, "w") do |f|
    f.write YAML.dump(token.to_hash)
  end
  redirect "/"
end

get '/sleep/:date' do
  res = token.get("https://api.fitbit.com/1.2/user/-/sleep/list.json?beforeDate=#{params[:date]}&sort=desc&offset=0&limit=50")
  res.parsed.to_json
end
