# frozen_string_literal: true

# Provides methods to the database manager for creating and fetching user credentials.
module UserManager
  def user_credentials(username)
    query('SELECT id, password FROM users WHERE username = $1', username).first
  end

  def create_user(username, password)
    query('INSERT INTO users (username, password) VALUES ($1, $2)', username, password)
  end
end
