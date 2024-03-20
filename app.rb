require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'

enable :sessions

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
  db = SQLite3::Database.new('db/filly.db')
  db.results_as_hash = true
  result = db.execute("SELECT * FROM users WHERE username = ?",username).first
  if result == nil
    redirect('/wrong_username')
  end
  pwdigest = result["pwdigest"]
  id = result["id"]
  
  if BCrypt::Password.new(pwdigest) == password
    session[:id] = id
    session[:username] = username
    p session[:id]
    redirect('/filly')
  else
    redirect('/wrong_password')
  end
end

get('/admin') do
  slim(:admin)
end

post('/genre/new') do
    genre = params[:genre]
    db = SQLite3::Database.new('db/filly.db')
    db.results_as_hash = true

    db.execute("INSERT INTO genre (name) VALUES (?)", genre)
    redirect('/admin')

end

get('/filly') do
  id = session[:id].to_i
  db = SQLite3::Database.new('db/filly.db')
  db.results_as_hash = true
  result = db.execute("SELECT movies.*, GROUP_CONCAT(genre.name, ', ') AS genre_names 
                      FROM movies 
                      LEFT JOIN genre_movies_rel ON movies.id = genre_movies_rel.movie_id 
                      LEFT JOIN genre ON genre_movies_rel.genre_id = genre.id 
                      WHERE movies.user_id = ? 
                      GROUP BY movies.id", id)
  
  
  p "Alla filmer/serier från result #{result}"
  slim(:"filly/index", locals: { filly: result })
end

post('/users/new') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]

  if password == password_confirm
    password_digest = BCrypt::Password.create(password)
    db = SQLite3::Database.new('db/filly.db')
    db.execute('INSERT INTO users (username,pwdigest) VALUES (?,?)',username,password_digest)
    redirect('/')
  else
    "Lösenorden matchade inte"
  end
end

get('/filly/new') do
  db = SQLite3::Database.new('db/filly.db')
  db.results_as_hash = true
  genres = db.execute("SELECT * FROM genre")

  slim(:"filly/new", locals: { genres: genres })
end

post('/filly/new') do
  title = params[:title]
  director = params[:director]
  genre = params[:genre]
  rating = params[:rating]
  db = SQLite3::Database.new("db/filly.db")
  db.execute("INSERT INTO movies (name, director, user_id, rating) VALUES (?, ?, ?, ?)", title, director, session[:id], rating)
  movies_id = db.last_insert_row_id
  genre_id = db.execute("SELECT id FROM genre WHERE name = ?", genre).first[0]
  p movies_id
  p genre_id
  db.execute("INSERT INTO genre_movies_rel (genre_id, movie_id) VALUES (?, ?)", genre_id, movies_id)
  redirect('/filly/new')
end

post '/filly/:movies/delete' do
  id = params[:movies].to_i
  db = SQLite3::Database.new('db/filly.db')
  db.execute("DELETE FROM movies WHERE id=?", id)
  db.execute("DELETE FROM genre_movies_rel WHERE movie_id=?", id)
  redirect('/filly')
end

post('/filly/:movies/update') do
  id = params[:movies].to_i
  title = params[:title]
  director = params[:director]
  genre = params[:genre]
  rating = params[:rating]

  db = SQLite3::Database.new("db/filly.db")
  db.execute("UPDATE movies SET name=?, director=?, rating=? WHERE id = ?", title, director, rating, id)

  genre_id = db.execute("SELECT id FROM genre WHERE name = ?", genre).first&.first
  if genre_id
    db.execute("INSERT INTO genre_movies_rel (genre_id, movie_id) VALUES (?, ?)", genre_id, id)
  end
  redirect('/filly')
end

get('/filly/:movies/edit') do
  id = params[:movies].to_i
  db = SQLite3::Database.new("db/filly.db")
  db.results_as_hash = true

  genres = db.execute("SELECT * FROM genre")

  result = db.execute("SELECT * FROM movies WHERE id = ?", id).first
  p "result är #{result}"
  slim(:"/filly/edit", locals: { result: result, genres: genres })
end

get('/cooldown') do
  session[:cooldown] = true
  session[:time1] = Time.now
  slim(:"filly/cooldown")
end