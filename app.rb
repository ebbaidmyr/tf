require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative './model.rb'

enable :sessions

include Model

before do 
  if !['/', '/showlogin', '/login', '/wrong_password', '/wrong_username'].include?(request.path_info) && session[:id].nil?
      redirect('/showlogin')
  end

  if request.path_info == '/admin' && session[:username] != 'admin'
      redirect('/filly')
  end
end

total_attempts = 3
first_cooldown = 2
max_cooldown = 500

before '/login' do
  session[:attempts] ||=0
  if session[:attempts] >= total_attempts
    cooldown = [first_cooldown * (2 ** (session[:attempts] - total_attempts)), max_cooldown].min
    if Time.now - (session[:last_attempt_time] || Time.now) < cooldown 
      halt 429, "För många försök, snela vänta #{cooldown - (Time.now - session[:last_attempt_time]).to_i} sekunder."
    end
  end
end

get('/') do
  slim(:register)
end

get('/showlogin') do
  slim(:login)
end

get('/wrong_password') do
  slim(:wrong_password)
end

get('/wrong_username') do
  slim(:wrong_username)
end

post('/login') do
  username = params[:username]
  password = params[:password]

  result = find_user(username)

  if result == nil
    redirect('/wrong_username')
  end

  pwdigest = result["pwdigest"]
  id = result["id"]
  

  if authenticate_user(password, pwdigest)
    session[:id] = id
    session[:username] = username
    redirect('/filly')
  else
    session[:last_attempt_time] = Time.now
    session[:attempts] += 1
    redirect('/wrong_password')
  end
end

get('/admin') do
  slim(:admin)
end

post('/genre/new') do
    if authenticate_admin(session[:username])
      genre = params[:genre]
      create_new_genre(genre)
      redirect('/admin')
    end
    redirect('/showlogin')
end

get('/filly') do
  id = session[:id].to_i
  result = get_movies(id)
  
  p "Alla filmer/serier från result #{result}"
  slim(:"filly/index", locals: { filly: result })
end

get('/same') do
  slim(:same)
end

get('/empty') do
  slim(:empty)
end

post('/users/new') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]

  if user_taken(username)
    redirect('/same')
  end

  if username == "" ||  password == ""
    redirect('/empty')
  end

  register_user(username, password, password_confirm)
end

get('/filly/new') do
  genres = get_genres()

  slim(:"filly/new", locals: { genres: genres })
end

post('/filly') do
  title = params[:title]
  director = params[:director]
  genre = params[:genre]
  type = params[:type]
  rating = params[:rating]

  if title == "" || director == ""
    redirect('/filly/new')
  else 
    create_movie(session[:id], title, director, type, rating, genre)
  end

  redirect('/filly/new')
end

post('/filly/:movies/delete') do
  movie_id = params[:movies]

  if authenticate_movie(session[:id], movie_id)
    delete_movie(movie_id)
  end

  redirect('/filly')
end

post('/filly/:movies/update') do
  movie_id = params[:movies].to_i
  title = params[:title]
  director = params[:director]
  genre = params[:genre]
  type = params[:type]
  rating = params[:rating]

  if title == "" || director == ""
    redirect('/filly/new')
  else
    create_movie(session[:id], title, director, type, rating, genre)
  end

  if authenticate_movie(session[:id], movie_id)
    update_movie(movie_id, title, director, type, rating, genre)
  end

  redirect('/filly')
end

get('/filly/:movies/edit') do
  id = params[:movies].to_i
  genres = get_genres()

  result = get_movie(id)
  slim(:"/filly/edit", locals: { result: result, genres: genres })
end