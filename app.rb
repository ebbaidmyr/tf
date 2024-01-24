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

post('/login') do
  username = params[:username]
  password = params[:password]
  db = SQLite3::Database.new('db/filly.db')
  db.results_as_hash = true
  result = db.execute("SELECT * FROM users WHERE username = ?",username).first
  pwdigest = result["pwdigest"]
  id = result["id"]
  
  if BCrypt::Password.new(pwdigest) == password
    session[:id] = id
    redirect('/filly')
  else
    "FEL LÖSEN!"
  end
end

get('/filly') do
  id = session[:id].to_i
  db = SQLite3::Database.new('db/filly.db')
  db.results_as_hash = true
  result = db.execute("SELECT * FROM filly WHERE user_id = ?",id)
  p "Alla filmer/serier från result #{result}"
  slim(:"filly/index",locals:{filly:result})
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