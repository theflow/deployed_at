require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'dm-timestamps'

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

  def set_proper_title
    self.title = "Deploy of revision #{head_rev}" if title.blank?
  end

  def set_number_of_changes
    self.changes = get_number_of_changes
  end

  def get_number_of_changes
    scm_log.blank? ? 0 : scm_log.scan(/^r\d+/).size
  end
end

class Project
  include DataMapper::Resource

  property :id,         Integer, :serial => true
  property :name,       String

  has n, :deploys

  has n, :subscriptions
  has n, :users, :through => :subscriptions

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

DataMapper.auto_upgrade!

get '/' do
  if @projects.size == 0
    @title = "Deployed It!"
    erb "<p>No deploys recorded yet</p>"
  else
    redirect "/projects/#{@projects.first.id}"
  end
end

get '/projects/:id' do
  @project = Project.get(params[:id])
  @deploys = @project.deploys.all(:order => [:created_at.desc])

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
end
