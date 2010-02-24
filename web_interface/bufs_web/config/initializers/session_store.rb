# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_bufs_web_session',
  :secret      => '1881b3649d82418fd89bc3b47fe8357d2c489c30b4d54efb1e0a22887c429d02bdffa59d6e4afdbc480cf50fe64a4e8614d14b3931ef7dababa1d5e912f44061'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
