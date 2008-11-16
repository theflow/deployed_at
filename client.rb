#!/usr/bin/ruby
require 'net/http'
require 'uri'
require 'cgi'

class DeployedItClient
  def initialize(service_root)
    @service_root = service_root
  end

  def new_deploy(user, title)
    deploy_body = File.read('test/changesets/two_changesets.txt')
    args = {'user'    => user,
            'title'   => title,
            'body'    => deploy_body,
            'project' => 'Main App' }

    url = URI.parse(@service_root + '/deploys')
    Net::HTTP.post_form(url, args)
  end
end

client = DeployedItClient.new('http://localhost:4567')
client.new_deploy(ENV['USER'], ARGV.first)
