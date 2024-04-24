require 'sinatra'
require 'sqlite3'
require 'bcrypt'

module Model

    def connect_to_db()
        db = SQLite3::Database.new('db/filly.db')
        db.results_as_hash = true
        return db
    end

    def find_user(username)
        db = connect_to_db()
        result = db.execute("SELECT * FROM users WHERE username = ?",username).first
        return result
    end

    def user_taken(username)
        db = connect_to_db()
        user_db = db.execute("SELECT username FROM users")

        user_db.each do |name|
            if name["username"] == username
                return true
            end
        end
        return false
    end

    def register_user(username, password, password_confirm)
        db = connect_to_db()

        if password == password_confirm
            password_digest = BCrypt::Password.create(password)
            db.execute('INSERT INTO users (username,pwdigest) VALUES (?,?)', username, password_digest)
        else
            "Lösenorden matchade inte"
        end
    end

    def authenticate_user(password, pwdigest)
        BCrypt::Password.new(pwdigest) == password
    end

    def authenticate_admin(username)
        return username == 'admin'
    end

    def create_new_genre(genre)
        db = connect_to_db()
        db.execute("INSERT INTO genre (name) VALUES (?)", genre)
    end

    def get_movies(user_id)
        db = connect_to_db()
        result = db.execute("SELECT movies.*, GROUP_CONCAT(genre.name, ', ') AS genre_names FROM movies LEFT JOIN genre_movies_rel ON movies.id = genre_movies_rel.movie_id LEFT JOIN genre ON genre_movies_rel.genre_id = genre.id WHERE movies.user_id = ? GROUP BY movies.id", user_id)
        return result
    end

    def get_genres()
        db = connect_to_db()
        genres = db.execute("SELECT * FROM genre")
        return genres
    end

    def create_movie(user_id, title, director, type, rating, genre)

        db = connect_to_db()
        db.execute("INSERT INTO movies (name, director, user_id, type, rating) VALUES (?, ?, ?, ?, ?)", title, director, user_id, type, rating)
        movies_id = db.last_insert_row_id
        genre_id = db.execute("SELECT id FROM genre WHERE name = ?", genre).first[0]
        db.execute("INSERT INTO genre_movies_rel (genre_id, movie_id) VALUES (?, ?)", genre_id, movies_id)
    end

    def authenticate_movie(user_id, movie_id)
        db = connect_to_db()
        movie_user_id = db.execute("SELECT user_id FROM movies WHERE id = ?", movie_id).first
        return movie_user_id["user_id"] == user_id
    end

    def delete_movie(movie_id)
        db = connect_to_db()
        db.execute("DELETE FROM movies WHERE id=?", movie_id)
        db.execute("DELETE FROM genre_movies_rel WHERE movie_id=?", movie_id)
    end

    def update_movie(movie_id, title, director, type, rating, genre)
        db = connect_to_db()

        db.execute("UPDATE movies SET name=?, director=?, type=?, rating=? WHERE id = ?", title, director, type, rating, movie_id)
        genre_id = db.execute("SELECT id FROM genre WHERE name = ?", genre).first
        if genre_id
            db.execute("INSERT INTO genre_movies_rel (genre_id, movie_id) VALUES (?, ?)", genre_id["id"], movie_id)
        end
    end

    def get_movie(movie_id)
        db = connect_to_db()
        result = db.execute("SELECT * FROM movies WHERE id = ?", movie_id).first

        return result
    end

end