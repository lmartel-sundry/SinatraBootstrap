require 'rubygems'
require 'twilio-ruby'
require 'sinatra'
require 'rest-client'
require 'sequel'
require 'rack/csrf'

raise "Missing environment variables" unless ENV['SECRET_TOKEN']

DB = Sequel.connect('sqlite://test.db')

DB.create_table? :users do
  primary_key :id
  String :email
  String :password_digest
  unique :email
end

configure do
  use Rack::Session::Cookie, secret: ENV['SECRET_TOKEN']
  use Rack::Csrf, :raise => true
end 

helpers do
  def logged_in?
    !session[:user].nil?
  end

  def current_user
    session[:user]
  end

  def csrf_token
    Rack::Csrf.csrf_token(env)
  end

  def csrf_tag
    Rack::Csrf.csrf_tag(env)
  end
end

class User < Sequel::Model
  plugin :secure_password
  plugin :validation_helpers

  def validate
    super
    validates_presence :email
    validates_unique :email
  end
end

# Routes

get '/' do
  erb :index
end

post '/signup' do
  phone = params[:phone]
  phone = nil if phone.length == 0
  email = params[:email]
  begin
    user = User.create email: email, password: params[:password], password_confirmation: params[:password_confirmation]
  rescue Sequel::ValidationFailed => error
    redirect '/?err=email_taken'
  end
  session[:user] = user.email
  redirect '/'
end

post '/login' do
  user = User[email: params[:email]]
  redirect '/?err=email_not_found' if user.nil?
  if user.authenticate(params[:password])
    session[:user] = user.email
    redirect '/'
  else 
    redirect '/?err=invalid_password'
  end
end

post '/logout' do
  session[:user] = nil
  redirect '/'
end
