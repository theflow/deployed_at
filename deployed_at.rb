require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'dm-timestamps'

DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/database.sqlite3")

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

  def self.find_or_create(name)
    project = self.first(:name => name)
    project || self.create(:name => name)
  end
end

DataMapper.auto_upgrade!

get '/' do
  @projects = Project.all

  if @projects.size == 0
    @title = "Deployed It!"
    erb "<p>No deploys recorded yet</p>"
  else
    redirect "/projects/#{@projects.first.id}"
  end
end

get '/projects/:id' do
  @projects = Project.all
  @project = Project.get(params[:id])
  @deploys = @project.deploys.all(:order => [:created_at.desc])

  @title = "Recent deploys for #{@project.name}"
  erb :list_deploys
end

get '/deploys/:id' do
  @projects = Project.all
  @deploy = Deploy.get(params[:id])
  @project = @deploy.project

  @title = "[#{@project.name}] #{@deploy.title}"
  erb :show_deploy
end

post '/deploys' do
  project = Project.find_or_create(params[:project])
  project.deploys.create(:title => params[:title],
                         :user => params[:user],
                         :scm_log => params[:scm_log],
                         :head_rev => params[:head_rev],
                         :current_rev => params[:current_rev])
end

helpers do
  def format_time(time)
    time.strftime('%b %d %H:%M')
  end
  
end