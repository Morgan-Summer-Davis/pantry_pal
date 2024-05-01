# frozen_string_literal: true

require 'pg'

require_relative 'recipe_manager'
require_relative 'ingredient_manager'
require_relative 'step_manager'
require_relative 'user_manager'

# This is the database management class for total recipe book application. It
# initializes the database on first boot up and establishes a connection, as well
# as provides a method for safe and formatted SQL queries. For methods to execute
# specific queries, see the relevant module.
class DatabaseManager
  include RecipeManager
  include IngredientManager
  include StepManager
  include UserManager

  def initialize(logger)
    dbname = ENV['RACK_ENV'] == 'test' ? 'test_morgan_davis_recipe_book' : 'morgan_davis_recipe_book'

    @logger = logger
    @db = if Sinatra::Base.production? then PG.connect(ENV['DATABASE_URL'])
          else
            begin
              PG.connect(dbname:)
            rescue PG::ConnectionBad
              initialize_database(dbname)
            end
          end
  end

  private

  def query(sql, *args)
    @logger.info "#{sql}: #{args}"
    result = @db.exec_params(sql, args)

    result.map.with_index { |_, index| result[index].transform_keys(&:to_sym) }
  end

  def initialize_database(dbname = 'morgan_davis_recipe_book')
    PG.connect(dbname: 'postgres').exec("CREATE DATABASE #{dbname}")
    # rubocop:disable Style/ExpandPathArguments
    # - Reason: `File.expand_path(__dir__)` has undesirable edge cases
    PG.connect(dbname:).exec(File.read("#{File.expand_path('..', __FILE__)}/schema.sql"))
    # rubocop:enable Style/ExpandPathArguments

    @logger.info 'Database initialized'
    PG.connect(dbname:)
  end
end
