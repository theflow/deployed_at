#!/usr/bin/ruby -rubygems
require 'rest-open-uri'
require 'uri'
require 'cgi'

class DeployedItClient
  def initialize(service_root)
    @service_root = service_root
  end

  def form_encoded(hash)
    encoded = []
    hash.each do |key, value|
      encoded << CGI.escape(key) + '=' + CGI.escape(value)
    end

    encoded.join('&')
  end

  def new_deploy(user, title)
    deploy_body = File.read('changesets/two_changesets.txt')
    representation = form_encoded({"user"  => user,
                                   "title" => title,
                                   "body"  => deploy_body,
                                   "project" => "Main Project" })

    response = open(@service_root + '/deploys', :method => :post, :body => representation)
  end
end

client = DeployedItClient.new('http://localhost:4567')
client.new_deploy(ENV['USER'], ARGV.first)
