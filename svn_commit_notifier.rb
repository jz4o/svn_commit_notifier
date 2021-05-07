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


  # fetch latest revision
  unless File.exists? "repositories/#{repository_name}"
    File.write("repositories/#{repository_name}", `svn info #{config['repository']} --username #{username} --password #{password} --non-interactive`[/Revision: (\d+)/, 1])
  end

  # check current revision
  current_revision = File.read("repositories/#{repository_name}").to_i

  # check latest revision
  latest_revision = `svn info #{config['repository']} --username #{username} --password #{password} --non-interactive`[/Revision: (\d+)/, 1].to_i

  return if current_revision == latest_revision

  commit_log = `svn log #{config['repository']} --username #{username} --password #{password} --limit #{latest_revision - current_revision} --non-interactive`
  post_to_slack config['slack_incoming_webhook_url'], "```#{commit_log}```"

  File.write("repositories/#{repository_name}", latest_revision)
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

