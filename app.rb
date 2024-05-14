require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative './model.rb'

enable :sessions

include Model

# Redirects to login page if not logged in, and restricts access to admin page
before do 
  if !['/', '/showlogin', '/login', '/wrong_password', '/wrong_username'].include?(request.path_info) && session[:id].nil?
      redirect('/showlogin')
  end

  if request.path_info == '/admin' && session[:username] != 'admin'
      redirect('/filly')
  end
end

# Limits login attempts and implements cooldown
total_attempts = 3
first_cooldown = 2
max_cooldown = 500

# Secure the user being hacked by a exponential cooldown function
before '/login' do
  session[:attempts] ||=0
  if session[:attempts] >= total_attempts
    cooldown = [first_cooldown * (2 ** (session[:attempts] - total_attempts)), max_cooldown].min
    if Time.now - (session[:last_attempt_time] || Time.now) < cooldown 
      halt 429, "För många försök, snela vänta #{cooldown - (Time.now - session[:last_attempt_time]).to_i} sekunder."
    end
  end
end

# Displays a register form
get('/') do
  slim(:register)
end

# Displays a login form
get('/showlogin') do
  slim(:login)
end

# Route for displaying wrong password page, displays an error message
get('/wrong_password') do
  slim(:wrong_password)
end

# Route for displaying wrong username page, displays an error message
get('/wrong_username') do
  slim(:wrong_username)
end

# Login route, authenticates user, else redirects user to landing page
#
# @param [String] username, The username entered by the user
# @param [String] password, The password entered by the user
# @see Model#find_user
# @see Model#authenticate_user
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

# Route for admin page
get('/admin') do
  slim(:admin)
end

# Route for creating new genre, if admin redirects to admin page, else redirects to /showlogin
#
# @param [String] genre, The new name of the genre
# @see Model#authenticate_admin
# @see Model#create_new_genre
post('/genre/new') do
    if authenticate_admin(session[:username])
      genre = params[:genre]
      create_new_genre(genre)
      redirect('/admin')
    end
    redirect('/showlogin')
end

# Route for displaying user's movies
get('/filly') do
  id = session[:id].to_i
  result = get_movies(id)
  
  p "Alla filmer/serier från result #{result}"
  slim(:"filly/index", locals: { filly: result })
end

# Displays various error messages
get('/same') do
  slim(:same)
end

# Displays that when creating a movie something was not filled in
get('/empty') do
  slim(:empty)
end

# Route for creating new user, if user is the same or blank, redirects to error page, else confirms registration
#
# @param [String] username, The new username entered by the user
# @param [String] password, The new password entered by the user
# @param [String] password_confirm, The confirmation of the password entered by the user
# @see Model#user_taken
# @see Model#register_user
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

# Displays a form to add new movie
# @see Model#get_genres
get('/filly/new') do
  genres = get_genres()
  slim(:"filly/new", locals: { genres: genres })
end

# Route for creating new movie
#
# @param [String] title, The title of the new movie
# @param [String] director, The director of the new movie
# @param [String] genre, The genre of the new movie
# @param [String] type, The type of the new movie
# @param [String] rating, The rating of the new movie
# @see Model#create_movie
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

# Route for deleting movies, if authenticated, lets user delete movie 
# @param [String], movie_id, The ID of the movie to be deleted
# @see Model#authenticate_movie
# @see Model#delete_movie
post('/filly/:movies/delete') do
  movie_id = params[:movies]

  if authenticate_movie(session[:id], movie_id)
    delete_movie(movie_id)
  end

  redirect('/filly')
end

# Route for updating movie, if authenticated, lets the user update the movie
# @param [Integer] movie_id, The ID of the movie to be updated
# @param [String] title, The new title of the movie
# @param [String] director, The new director of the movie
# @param [String] genre, The new genre of the movie
# @param [String] type, The new type of the movie
# @param [String] rating, The new rating of the movie
# @see Model#create_movie
# @see Model#authenticate_movie
# @see Model#update_movie
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

# Displays the edited movie
#
# @param [Integer] id, The ID of the movie to be edited
get('/filly/:movies/edit') do
  id = params[:movies].to_i
  genres = get_genres()
  result = get_movie(id)
  slim(:"/filly/edit", locals: { result: result, genres: genres })
end
