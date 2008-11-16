require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'dm-timestamps'

DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/database.sqlite3")

class Deploy
  include DataMapper::Resource

  property :id,         Integer, :serial => true
  property :title,      String
  property :user,       String
  property :changes,    Integer, :default => 0
  property :body,       Text
  property :project_id, Integer
  property :created_at, DateTime

  belongs_to :project

  before :save, :set_number_of_changes

  def set_number_of_changes
    self.changes = get_number_of_changes
  end

  def get_number_of_changes
    body.blank? ? 0 : body.scan(/^r\d+/).size
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
  @deploys = Deploy.all(:order => [:created_at.desc])
  erb :index
end

post '/deploys' do
  project = Project.find_or_create(params[:project])
  puts project.id
  project.deploys.create(:title => params[:title], :user => params[:user], :body => params[:body])
end

get '/deploys/:id' do
  @deploy = Deploy.get(params[:id])
  erb :show
end
