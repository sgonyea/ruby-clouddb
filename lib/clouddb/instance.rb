module CloudDB
  class Instance

    attr_reader :connection

    attr_reader :id
    attr_reader :name
    attr_reader :hostname
    attr_reader :flavor_id
    attr_reader :root_enabled
    attr_reader :volume_used
    attr_reader :volume_size
    attr_reader :status
    attr_reader :created
    attr_reader :updated
    attr_reader :links

    # Creates a new CloudDB::Instance object representing a database instance.
    def initialize(connection,id)
      @connection    = connection
      @id            = id
      @dbmgmthost   = connection.dbmgmthost
      @dbmgmtpath   = connection.dbmgmtpath
      @dbmgmtport   = connection.dbmgmtport
      @dbmgmtscheme = connection.dbmgmtscheme
      populate
      self
    end

    # Updates the information about the current instance object by making an API call.
    def populate
      response = @connection.dbreq("GET", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}", @dbmgmtport, @dbmgmtscheme)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      data = JSON.parse(response.body)['instance']
      @id           = data["id"]
      @name         = data["name"]
      @hostname     = data["hostname"]
      @flavor_id    = data["flavor"]["id"] if data["flavor"]
      @root_enabled = data["rootEnabled"]
      @volume_used  = data["volume"]["used"] if data["volume"]
      @volume_size  = data["volume"]["size"] if data["volume"]
      @status       = data["status"]
      @created      = data["created"]
      @updated      = data["updated"]
      @links        = data["links"]
      true
    end
    alias :refresh :populate

    # Lists the databases associated with this instance
    #
    # Example:
    #   i.list_databases
    def list_databases
      response = @connection.dbreq("GET", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}/databases", @dbmgmtport, @dbmgmtscheme)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      CloudDB.symbolize_keys(JSON.parse(response.body)["databases"])
    end
    alias :databases :list_databases

    # Returns a CloudDB::Database object for the given database name.
    def get_database(name)
      CloudDB::Database.new(self, name)
    end
    alias :database :get_database

    # Creates brand new databases and associates them with the current instance. Returns true if successful.
    #
    # Options for each database in the array:
    #   :name - Specifies the database name for creating the database. *required*
    #   :character_set - Set of symbols and encodings. The default character set is utf8.
    #   :collate - Set of rules for comparing characters in a character set. The default value for collate is
    #              utf8_general_ci.
    def create_databases(databases)
      (raise CloudDB::Exception::Syntax, "Must provide at least one database in the array") if (!databases.is_a?(Array) || databases.size < 1)

      body = Hash.new
      body[:databases] = Array.new

      for database in databases
        new_database = Hash.new
        new_database[:name]          = database[:name] or raise CloudDB::Exception::MissingArgument, "Must provide a name for each database"
        new_database[:character_set] = database[:character_set] || 'utf8'
        new_database[:collate]       = database[:collate] || 'utf8_general_ci'
        (raise CloudDB::Exception::Syntax, "Database names must be 64 characters or less") if database[:name].size > 64

        body[:databases] << new_database
      end

      response = @connection.dbreq("POST", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}/databases", @dbmgmtport, @dbmgmtscheme, {}, body.to_json)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      true
    end

    # Creates a brand new database and associates it with the current instance. Returns true if successful.
    #
    # Options:
    #   :name - Specifies the database name for creating the database. *required*
    #   :character_set - Set of symbols and encodings. The default character set is utf8.
    #   :collate - Set of rules for comparing characters in a character set. The default value for collate is
    #              utf8_general_ci.
    def create_database(options={})
      new_databases = Array.new
      new_databases << options
      create_databases new_databases
    end

    # Lists the users associated with the current Instance
    #
    # Example:
    #   i.list_users
    def list_users
      response = @connection.dbreq("GET", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}/users", @dbmgmtport, @dbmgmtscheme)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      CloudDB.symbolize_keys(JSON.parse(response.body)["users"])
    end
    alias :users :list_users

    # Returns a CloudDB::User object for the given user name.
    def get_user(name)
      CloudDB::User.new(self, name)
    end
    alias :user :get_user

    # Creates brand new users and associates them with the current instance. Returns true if successful.
    #
    # Options for each user in the array:
    #   :name - Name of the user for the database(s). *required*
    #   :password - User password for database access. *required*
    #   :databases - An array of databases with at least one database. *required*
    def create_users(users)
      (raise CloudDB::Exception::Syntax, "Must provide at least one user in the array") if (!users.is_a?(Array) || users.size < 1)

      body = Hash.new
      body[:users] = Array.new

      for user in users
        new_user = Hash.new
        new_user[:name]      = user[:name] or raise CloudDB::Exception::MissingArgument, "Must provide a name for each user"
        new_user[:password]  = user[:password] or raise CloudDB::Exception::MissingArgument, "Must provide a password for each user"
        new_user[:databases] = user[:databases]
        (raise CloudDB::Exception::Syntax, "User names must be 16 characters or less") if user[:name].size > 16
        (raise CloudDB::Exception::Syntax, "Must provide at least one database in each user :databases array") if (!user[:databases].is_a?(Array) || user[:databases].size < 1)

        body[:users] << new_user
      end

      response = @connection.dbreq("POST", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}/users", @dbmgmtport, @dbmgmtscheme, {}, body.to_json)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      true
    end

    # Creates a brand new user and associates it with the current instance. Returns true if successful.
    #
    # Options:
    #   :name - Name of the user for the database(s). *required*
    #   :password - User password for database access. *required*
    #   :databases - An array of databases with at least one database. *required*
    def create_user(options={})
      new_users = Array.new
      new_users << options
      create_users new_users
    end

    # Enables the root user for the specified database instance and returns the root password.
    #
    # Example:
    #   i.enable_root
    #   => true
    def enable_root()
      response = @connection.dbreq("POST", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}/root", @dbmgmtport, @dbmgmtscheme, {})
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      @root_enabled = true
      body = JSON.parse(response.body)['user']
      return body
    end

    # Returns true if root user is enabled for the specified database instance or false otherwise.
    #
    # Example:
    #   i.root_enabled?
    #   => true
    def root_enabled?()
      response = @connection.dbreq("GET", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}/root", @dbmgmtport, @dbmgmtscheme, {})
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      @root_enabled = JSON.parse(response.body)['rootEnabled']
      return @root_enabled
    end

    # This operation changes the memory size of the instance, assuming a valid flavorRef is provided. Restarts MySQL in
    # the process.
    #
    # Options:
    #   :flavor_ref - reference to a flavor as specified in the response from the List Flavors API call. *required*
    def resize(options={})
      body = Hash.new
      body[:resize] = Hash.new

      body[:resize][:flavorRef]  = options[:flavor_ref] or raise CloudDB::Exception::MissingArgument, "Must provide a flavor to create an instance"

      response = @connection.dbreq("POST", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}/action", @dbmgmtport, @dbmgmtscheme, {}, body.to_json)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      true
    end

    # This operation supports resizing the attached volume for an instance. It supports only increasing the volume size
    # and does not support decreasing the size. The volume size is in gigabytes (GB) and must be an integer.
    #
    # Options:
    #   :size - specifies the volume size in gigabytes (GB). The value specified must be between 1 and 10. *required*
    def resize_volume(options={})
      body = Hash.new
      body[:resize] = Hash.new
      volume = Hash.new
      body[:resize][:volume] = volume

      volume[:size] = options[:size] or raise CloudDB::Exception::MissingArgument, "Must provide a volume size"
      (raise CloudDB::Exception::Syntax, "Volume size must be a value between 1 and 10") if !options[:size].is_a?(Integer) || options[:size] < 1 || options[:size] > 10

      response = @connection.dbreq("POST", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}/action", @dbmgmtport, @dbmgmtscheme, {}, body.to_json)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      true
    end

    # The restart operation will restart only the MySQL Instance. Restarting MySQL will erase any dynamic configuration
    # settings that you have made within MySQL.
    def restart()
      body = Hash.new
      body[:restart] = Hash.new

      response = @connection.dbreq("POST", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}/action", @dbmgmtport, @dbmgmtscheme, {}, body.to_json)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^20.$/)
      true
    end

    # Deletes the current instance object.  Returns true if successful, raises an exception otherwise.
    def destroy!
      response = @connection.dbreq("DELETE", @dbmgmthost, "#{@dbmgmtpath}/instances/#{CloudDB.escape(@id.to_s)}", @dbmgmtport, @dbmgmtscheme)
      CloudDB::Exception.raise_exception(response) unless response.code.to_s.match(/^202$/)
      true
    end

  end
end
