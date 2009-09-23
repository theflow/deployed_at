$: << File.join(File.dirname(__FILE__), '..')

require 'rubygems'
require 'context'
require 'mocha'

require 'deployed_at'


def create_user(attributes = {})
  default_attributes = {
    :email => 'test@example.org'
  }
  User.create(default_attributes.merge(attributes))
end

def create_project(attributes = {})
  default_attributes = {
    :name => 'Test Project'
  }
  Project.create(default_attributes.merge(attributes))
end

def create_deploy(attributes = {})
  default_attributes = {
    :title => 'Test deploy',
    :user => 'thedude',
    :head_rev => '42',
    :current_rev => '23',
    :scm_log => File.read('changesets/two_changesets.txt'),
    :project => create_project
  }
  Deploy.create(default_attributes.merge(attributes))
end

def create_subscription(attributes = {})
  default_attributes = {
    :project => create_project,
    :user => create_user
  }
  Subscription.create(default_attributes.merge(attributes))
end
