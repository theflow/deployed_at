require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'dm-timestamps'
require 'net/smtp'

DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/database.sqlite3")

enable :sessions

class Deploy
  include DataMapper::Resource

  property :id,          Integer, :serial => true
  property :title,       String
  property :user,        String
  property :head_rev,    String
  property :current_rev, String
  property :changes,     Integer, :default => 0
  property :scm_log,     Text
  property :project_id,  Integer
  property :created_at,  DateTime

  belongs_to :project

  before :save, :set_number_of_changes
  before :save, :set_proper_title

  after :save, :notify

  def set_proper_title
    self.title = "Deploy of revision #{head_rev}" if title.blank?
  end

  def set_number_of_changes
    self.changes = get_number_of_changes
  end

  def get_number_of_changes
    scm_log.blank? ? 0 : scm_log.scan(/^r\d+/).size
  end

  def notify
    DeployMailer.send(project, current_rev, head_rev, scm_log)
  end

  def month
    created_at.strftime('%Y-%m')
  end

  def self.in_month(year_month)
    year, month = year_month.split('-')
    next_month = "#{year}-%02i" % (month.to_i + 1)
    all(:created_at.gte => year_month, :created_at.lt => next_month, :order => [:created_at.desc])
  end
end

class Project
  include DataMapper::Resource

  property :id,         Integer, :serial => true
  property :name,       String

  has n, :deploys

  has n, :subscriptions
  has n, :users, :through => :subscriptions

  def all_deploys_grouped_by_date
    deploys.all(:order => [:created_at.desc]).inject({}) do |groups, deploy|
      (groups[deploy.month] ||= []) << deploy
      groups
    end
  end

  def self.find_or_create(name)
    project = self.first(:name => name)
    project || self.create(:name => name)
  end
end

class User
  include DataMapper::Resource

  property :id,         Integer, :serial => true
  property :email,      String

  has n, :subscriptions
  has n, :projects, :through => :subscriptions

  def manage_subscriptions(param_hash)
    subscriptions.clear
    subscriptions.save
    param_hash.keys.each do |project_id|
      subscriptions.create(:project_id => project_id)
    end
  end

  def self.find_or_create(email)
    first(:email => email) || create(:email => email)
  end
end

class Subscription
  include DataMapper::Resource

  property :id,         Integer, :serial => true

  belongs_to :project
  belongs_to :user
end

class DeployMailer
  class << self
    attr_accessor :config
  end

  def self.send(project, current_rev, head_rev, svn_log)
    recipients = project.users.map { |u| u.email }
    return if recipients.empty?

    message_body = format_msg(project.name, current_rev, head_rev, svn_log)
    send_by_smtp(message_body, 'DeployedAt <deployed_it@example.org>', recipients)
  end

  def self.send_by_smtp(body, from, to)
    Net::SMTP.start(config[:host], config[:port], 'localhost', config[:user], config[:pass], config[:auth]) do |smtp|
      smtp.send_message(body, from, to)
    end
  end

  def self.format_msg(project_name, current_rev, head_rev, svn_log)
    msg = <<END_OF_MESSAGE
From: DeployedIt <deployed_it@example.org>
To: DeployedIt <deployed_it@example.org>
Subject: [DeployedIt] #{project_name} deploy


* Deployment started at #{Time.now}

* Changes in this deployment:

#{svn_log}

END_OF_MESSAGE
  end
end

CONFIG_FILE = File.join(File.dirname(__FILE__), 'config.yml')

if File.exist?(CONFIG_FILE)
  DeployMailer.config = YAML::load_file(CONFIG_FILE)['smtp_settings']
else
  puts ' Please create a config file by copying the example config:'
  puts ' $ cp config.example.yml config.yml'
  exit
end

DataMapper.auto_upgrade!

get '/' do
  @deploys = Deploy.all(:order => [:created_at.desc], :limit => 15)

  @title = 'Recent deploys'
  erb :dashboard
end

get '/projects/:id' do
  @project = Project.get(params[:id])
  if params[:show]
    @last_deploys = @project.deploys.in_month(params[:show])
  else
    @last_deploys = @project.deploys.all(:order => [:created_at.desc], :limit => 10)
  end

  @grouped_deploys = @project.all_deploys_grouped_by_date
  @years = @grouped_deploys.keys.map { |month| month.split('-').first }.uniq

  @title = "Recent deploys for #{@project.name}"
  erb :deploys_list
end

get '/deploys/:id' do
  @deploy = Deploy.get(params[:id])
  @project = @deploy.project

  @title = "[#{@project.name}] #{@deploy.title}"
  erb :deploys_show
end

post '/deploys' do
  project = Project.find_or_create(params[:project])
  project.deploys.create(:title => params[:title],
                         :user => params[:user],
                         :scm_log => params[:scm_log],
                         :head_rev => params[:head_rev],
                         :current_rev => params[:current_rev])
end

get '/session' do
  @title = 'Log in'
  erb :session_show
end

post '/session' do
  redirect '/session' and return if params[:email].blank?

  user = User.find_or_create(params[:email])
  session[:user_id] = user.id

  redirect '/subscriptions'
end

get '/subscriptions' do
  redirect '/session' and return if logged_out?

  @subscribed_projects = current_user.projects

  @title = 'Your subscriptions'
  erb :subscriptions_list
end

post '/subscriptions' do
  redirect '/session' and return if logged_out?

  current_user.manage_subscriptions(params)
  redirect 'subscriptions'
end

before do
  @projects = Project.all if request.get?
end

helpers do
  def logged_out?
    session[:user_id].blank?
  end

  def current_user
    @user ||= User.get(session[:user_id])
  end

  def format_time(time)
    time.strftime('%b %d %H:%M')
  end

  def link_to_month(month_name, month, project, grouped_deploys)
    number_of_deploys = grouped_deploys.has_key?(month) ? grouped_deploys[month].size : 0
    if number_of_deploys == 0
      month_name
    else
      "<a href=\"/projects/#{project.id}?show=#{month}\">#{month_name}</a> <small>(#{number_of_deploys})</small>"
    end
  end
end
