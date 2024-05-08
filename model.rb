require 'sinatra'
require 'sqlite3'
require 'bcrypt'

module Model

    # Connects to the database
    #
    # @return [SQLite3::Database] which is the database connection
    def connect_to_db()
        db = SQLite3::Database.new('db/filly.db')
        db.results_as_hash = true
        return db
    end

    # Finds a user by username
    #
    # @param [String] username, The username to search for
    #
    # @return [Hash] The user's data
    # @return [nil] if user not found
    def find_user(username)
        db = connect_to_db()
        result = db.execute("SELECT * FROM users WHERE username = ?",username).first
        return result
    end

    # Checks if a username is already taken
    #
    # @param [String] username, The username to check
    #
    # @return [Boolean] true, if the username is taken, false otherwise
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

    # Registers a new user
    #
    # @param [String] username, The new username
    # @param [String] password, The new password
    # @param [String] password_confirm, The confirmation of the new password
    #
    # @return [nil] if passwords do not match
    def register_user(username, password, password_confirm)
        db = connect_to_db()

        if password == password_confirm
            password_digest = BCrypt::Password.create(password)
            db.execute('INSERT INTO users (username,pwdigest) VALUES (?,?)', username, password_digest)
        else
            "Lösenorden matchade inte"
        end
    end

    # Authenticates a user
    #
    # @param [String] password, The entered password
    # @param [String] pwdigest, The stored password digest
    #
    # @return [Boolean] true if the password is correct, false otherwise
    def authenticate_user(password, pwdigest)
        BCrypt::Password.new(pwdigest) == password
    end

    # Checks if a user is an admin
    #
    # @param [String] username, The username to check
    #
    # @return [Boolean] true, if the user is an admin, false otherwise
    def authenticate_admin(username)
        return username == 'admin'
    end

    # Creates a new genre
    #
    # @param [String] genre, The name of the new genre
    #
    # @return [nil]
    def create_new_genre(genre)
        db = connect_to_db()
        db.execute("INSERT INTO genre (name) VALUES (?)", genre)
    end

    # Retrieves movies belonging to a user
    #
    # @param [Integer] user_id, The ID of the user
    #
    # @return [Array] containing data of the user's movies
    def get_movies(user_id)
        db = connect_to_db()
        result = db.execute("SELECT movies.*, GROUP_CONCAT(genre.name, ', ') AS genre_names FROM movies LEFT JOIN genre_movies_rel ON movies.id = genre_movies_rel.movie_id LEFT JOIN genre ON genre_movies_rel.genre_id = genre.id WHERE movies.user_id = ? GROUP BY movies.id", user_id)
        return result
    end

    # Collect all genres
    #
    # @return [Array] containing data of all genres
    def get_genres()
        db = connect_to_db()
        genres = db.execute("SELECT * FROM genre")
        return genres
    end

    # Creates a new movie
    #
    # @param [Integer] user_id, The ID of the user
    # @param [String] title, The title of the new movie
    # @param [String] director, The director of the new movie
    # @param [String] type, The type of the new movie
    # @param [String] rating, The rating of the new movie
    # @param [String] genre, The genre of the new movie
    #
    # @return [nil]
    def create_movie(user_id, title, director, type, rating, genre)

        db = connect_to_db()
        db.execute("INSERT INTO movies (name, director, user_id, type, rating) VALUES (?, ?, ?, ?, ?)", title, director, user_id, type, rating)
        movies_id = db.last_insert_row_id
        genre_id = db.execute("SELECT id FROM genre WHERE name = ?", genre).first[0]
        db.execute("INSERT INTO genre_movies_rel (genre_id, movie_id) VALUES (?, ?)", genre_id, movies_id)
    end

    # Authenticates if a user owns a movie
    #
    # @param [Integer] user_id The ID of the user
    # @param [Integer] movie_id The ID of the movie
    #
    # @return [Boolean] true if the user owns the movie, false otherwise
    def authenticate_movie(user_id, movie_id)
        db = connect_to_db()
        movie_user_id = db.execute("SELECT user_id FROM movies WHERE id = ?", movie_id).first
        return movie_user_id["user_id"] == user_id
    end

    # Deletes a movie
    #
    # @param [Integer] movie_id, The ID of the movie to delete
    #
    # @return [nil]
    def delete_movie(movie_id)
        db = connect_to_db()
        db.execute("DELETE FROM movies WHERE id=?", movie_id)
        db.execute("DELETE FROM genre_movies_rel WHERE movie_id=?", movie_id)
    end

    # Updates a movie
    #
    # @param [Integer] movie_id, The ID of the movie to update
    # @param [String] title, The new title of the movie
    # @param [String] director, The new director of the movie
    # @param [String] type, The new type of the movie (e.g., movie or series)
    # @param [String] rating, The new rating of the movie
    # @param [String] genre, The new genre of the movie
    #
    # @return [nil]
    def update_movie(movie_id, title, director, type, rating, genre)
        db = connect_to_db()

        db.execute("UPDATE movies SET name=?, director=?, type=?, rating=? WHERE id = ?", title, director, type, rating, movie_id)
        genre_id = db.execute("SELECT id FROM genre WHERE name = ?", genre).first
        if genre_id
            db.execute("INSERT INTO genre_movies_rel (genre_id, movie_id) VALUES (?, ?)", genre_id["id"], movie_id)
        end
    end

    # Retrieves data of a specific movie
    #
    # @param [Integer] movie_id The ID of the movie
    #
    # @return [Hash] containing data of the movie
    def get_movie(movie_id)
        db = connect_to_db()
        result = db.execute("SELECT * FROM movies WHERE id = ?", movie_id).first
        return result
    end
end