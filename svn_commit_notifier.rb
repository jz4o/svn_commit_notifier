require 'json'
require 'net/http'
require 'yaml'

include Clockwork

configure do |config|
  config[:tz] = 'Asia/Tokyo'
end

every(5.minutes, 'job') do
  main
end

def main
  config = YAML.load File.read('config/config.yml')

  repository_name = config['repository'].split('/').last
  username = config['username']
  password = config['password']


  # checkout
  unless File.exists? "repositories/#{repository_name}"
    `svn checkout #{config['repository']} --username #{username} --password #{password} --non-interactive repositories/#{repository_name}`
  end

  # check current revision
  current_revision = `svn info repositories/#{repository_name}`[/Revision: (\d+)/, 1].to_i

  # update
  `svn up repositories/#{repository_name} --username #{username} --password #{password}`

  # check updated revision
  updated_revision = `svn info repositories/#{repository_name}`[/Revision: (\d+)/, 1].to_i

  # check for updated
  puts "current_revision: #{current_revision}"
  puts "updated_revision: #{updated_revision}"

  return if current_revision == updated_revision

  commit_log = `svn log repositories/#{repository_name} --username #{username} --password #{password} --limit #{updated_revision - current_revision}`
  post_to_slack config['slack_incoming_webhook_url'], "```#{commit_log}```"
end

def post_to_slack(webhook_url, message)
  uri = URI.parse webhook_url

  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true

  http.start do
    request = Net::HTTP::Post.new uri.path
    request.set_form_data(payload: {text: message}.to_json)
    http.request request
  end
end

