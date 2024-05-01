ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'rack/test'
require 'fileutils'
require 'pg'
require 'minitest/hooks'

require_relative '../recipe_book'

class RecipeBookTest < Minitest::Test
  include Rack::Test::Methods
  include Minitest::Hooks

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def db
    PG.connect(dbname: 'test_morgan_davis_recipe_book')
  end

  def recipe_1_params_hash
    { "recipe_name"=>"Ham Sandwich", "2_ingredient_amount_in_recipe"=>"2", "3_ingredient_amount_in_recipe"=>"",
      "1_ingredient_amount_in_recipe"=>"1/5", "1_step_direction"=>"Assemble sandwich",
      "1_step_notes"=>"You should be able to figure it out.", "id"=>"1" }
  end

  def pantry_params_hash
    { "6_ingredient_name"=>"avocado", "6_ingredient_cost"=>"$0.74", "6_ingredient_amount_in_pantry"=>"4",
      "3_ingredient_name"=>"jar of mayonnaise", "3_ingredient_cost"=>"$5.69", "3_ingredient_amount_in_pantry"=>"1",
      "4_ingredient_name"=>"pack of turkey", "4_ingredient_cost"=>"$4.99", "4_ingredient_amount_in_pantry"=>"2/3",
      "2_ingredient_name"=>"slice of bread", "2_ingredient_cost"=>"$0.17", "2_ingredient_amount_in_pantry"=>"30",
      "5_ingredient_name"=>"egg", "5_ingredient_cost"=>"$5.50", "5_ingredient_amount_in_pantry"=>"",
      "1_ingredient_name"=>"pack of sliced ham", "1_ingredient_cost"=>"$3.99" }
  end

  def development_session
    { 'rack.session' => { username: 'development', user_id: '1' } }
  end

  def before_all
    super
    PG.connect(dbname: 'postgres').exec("CREATE DATABASE test_morgan_davis_recipe_book")
  end

  def after_all
    super
    db = PG.connect(dbname: 'postgres')

    db.exec(<<~SQL
    SELECT pg_terminate_backend(pg_stat_activity.pid)
      FROM pg_stat_activity
      WHERE pg_stat_activity.datname = 'test_morgan_davis_recipe_book'
        AND pid <> pg_backend_pid();
    SQL
    )

    db.exec("DROP DATABASE test_morgan_davis_recipe_book;")
  end

  def insert_test_data(filename = 'test_data')
    db.exec(File.read("#{File.expand_path('..', __FILE__)}/#{filename}.sql"))
  end

  def assert_logged_in
    assert_equal 302, last_response.status
    assert_equal 'You must be logged in to do that.', session[:error]
    get last_response['Location']
    assert_includes last_response.body, 'Login'
  end

  def setup
    db.exec(File.read("#{File.expand_path('../..', __FILE__)}/db/schema.sql"))
  end

  def teardown
    db.exec(File.read("#{File.expand_path('..', __FILE__)}/drop_tables.sql"))
  end

  def test_home_page
    get '/'
    assert_equal 302, last_response.status
    assert_nil session[:error]
    get last_response['Location']
    assert_includes last_response.body, 'Login'

    get '/', {}, development_session
    assert_equal 302, last_response.status
    get last_response['Location']
    assert_includes last_response.body, 'Last Made'
  end

  def test_recipes_list_page
    get '/recipes?page=1'
    assert_logged_in

    insert_test_data('test_data')

    get '/recipes?page=1', {}, development_session
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Last Made'
    assert_includes last_response.body, 'Ham Sandwich'
    assert_equal '1', last_request.params['page']
    refute_includes last_response.body, '<<'

    get '/recipes'
    assert_equal 302, last_response.status
    assert_nil session[:error]
    get last_response['Location']
    assert_includes last_response.body, 'Last Made'
    assert_equal '1', last_request.params['page']
  end

  def test_recipe_list_pagination
    insert_test_data('test_pagination_data')

    get '/recipes?page=1', {}, development_session
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Last Made'
    assert_includes last_response.body.gsub(' ', ''), ">></p>\n</a>"
    refute_includes last_response.body.gsub(' ', ''), "<<</p>\n</a>"

    get '/recipes?page=5'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Last Made'
    assert_includes last_response.body.gsub(' ', ''), ">></p>\n</a>"
    assert_includes last_response.body.gsub(' ', ''), "<<</p>\n</a>"

    get '/recipes?page=10'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Last Made'
    refute_includes last_response.body.gsub(' ', ''), ">></p>\n</a>"
    assert_includes last_response.body.gsub(' ', ''), "<<</p>\n</a>"

    get '/recipes?page=100'
    assert_equal 302, last_response.status
    assert_equal 'Page number out of range', session[:error]
    get last_response['Location']
    assert_includes last_response.body, 'Last Made'
    assert_equal '1', last_request.params['page']
    assert_includes last_response.body.gsub(' ', ''), ">></p>\n</a>"
    refute_includes last_response.body.gsub(' ', ''), "<<</p>\n</a>"
  end

  def test_recipe_page
    get '/recipes/1?ingredients_page=1&directions_page=1'
    assert_logged_in

    insert_test_data('test_data')

    get '/recipes/1?ingredients_page=1&directions_page=1', {}, development_session
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h2>Ham Sandwich</h2>'
    refute_includes last_response.body, '<<'

    get '/recipes/1'
    assert_equal 302, last_response.status
    assert_nil session[:error]
    get last_response['Location']
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h2>Ham Sandwich</h2>'
    assert_equal '1', last_request.params['ingredients_page']
    assert_equal '1', last_request.params['directions_page']
  end

  def test_recipe_pagination
    insert_test_data('test_pagination_data')

    get '/recipes/1?ingredients_page=1&directions_page=1', {}, development_session
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body.gsub(' ', ''), ">></p>\n</a>"
    refute_includes last_response.body.gsub(' ', ''), "<<</p>\n</a>"

    get '/recipes/1?ingredients_page=5&directions_page=5'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body.gsub(' ', ''), ">></p>\n</a>"
    assert_includes last_response.body.gsub(' ', ''), "<<</p>\n</a>"

    get '/recipes/1?ingredients_page=10&directions_page=10'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    refute_includes last_response.body.gsub(' ', ''), ">></p>\n</a>"
    assert_includes last_response.body.gsub(' ', ''), "<<</p>\n</a>"

    get '/recipes/1?ingredients_page=1&directions_page=10'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body.gsub(' ', ''), ">></p>\n</a>"
    assert_includes last_response.body.gsub(' ', ''), "<<</p>\n</a>"

    get '/recipes/1?ingredients_page=5&directions_page=100'
    assert_equal 302, last_response.status
    assert_equal 'Page number out of range', session[:error]
    get last_response['Location']
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_equal '5', last_request.params['ingredients_page']
    assert_equal '1', last_request.params['directions_page']

    get '/recipes/1?ingredients_page=100&directions_page=5'
    assert_equal 302, last_response.status
    assert_equal 'Page number out of range', session[:error]
    get last_response['Location']
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_equal '1', last_request.params['ingredients_page']
    assert_equal '5', last_request.params['directions_page']

    get '/recipes/1?ingredients_page=100&directions_page=100'
    assert_equal 302, last_response.status
    assert_equal 'Page number out of range', session[:error]
    get last_response['Location']
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_equal '1', last_request.params['ingredients_page']
    assert_equal '1', last_request.params['directions_page']
  end

  def test_pantry_page
    get '/pantry?in_stock_page=1&out_of_stock_page=1'
    assert_logged_in

    insert_test_data('test_data')

    get '/pantry?in_stock_page=1&out_of_stock_page=1', {}, development_session
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h2>My Pantry</h2>'
    assert_includes last_response.body, 'avocado'
    refute_includes last_response.body, '<<'

    get '/pantry'
    assert_equal 302, last_response.status
    assert_nil session[:error]
    get last_response['Location']
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h2>My Pantry</h2>'
    assert_includes last_response.body, 'avocado'
    refute_includes last_response.body, '<<'
  end

  def test_pantry_pagination
    insert_test_data('test_pagination_data')

    get '/pantry?in_stock_page=1&out_of_stock_page=1', {}, development_session
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body.gsub(' ', ''), ">></p>\n</a>"
    refute_includes last_response.body.gsub(' ', ''), "<<</p>\n</a>"

    get '/pantry?in_stock_page=5&out_of_stock_page=5'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body.gsub(' ', ''), ">></p>\n</a>"
    assert_includes last_response.body.gsub(' ', ''), "<<</p>\n</a>"

    get '/pantry?in_stock_page=10&out_of_stock_page=10'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    refute_includes last_response.body.gsub(' ', ''), ">></p>\n</a>"
    assert_includes last_response.body.gsub(' ', ''), "<<</p>\n</a>"

    get '/pantry?in_stock_page=1&out_of_stock_page=10'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body.gsub(' ', ''), ">></p>\n</a>"
    assert_includes last_response.body.gsub(' ', ''), "<<</p>\n</a>"

    get '/pantry?in_stock_page=5&out_of_stock_page=100'
    assert_equal 302, last_response.status
    assert_equal 'Page number out of range', session[:error]
    get last_response['Location']
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_equal '5', last_request.params['in_stock_page']
    assert_equal '1', last_request.params['out_of_stock_page']

    get '/pantry?in_stock_page=100&out_of_stock_page=5'
    assert_equal 302, last_response.status
    assert_equal 'Page number out of range', session[:error]
    get last_response['Location']
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_equal '1', last_request.params['in_stock_page']
    assert_equal '5', last_request.params['out_of_stock_page']

    get '/pantry?in_stock_page=100&out_of_stock_page=100'
    assert_equal 302, last_response.status
    assert_equal 'Page number out of range', session[:error]
    get last_response['Location']
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_equal '1', last_request.params['in_stock_page']
    assert_equal '1', last_request.params['out_of_stock_page']
  end

  def test_new_recipe_page
    get '/recipes/new'
    assert_logged_in

    insert_test_data('test_data')

    get '/recipes/new', {}, development_session
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, "value=\"\""
    assert_includes last_response.body, 'placeholder="Recipe Name"'
  end

  def test_edit_recipe_page
    get '/recipes/1/edit'
    assert_logged_in

    insert_test_data('test_data')

    get '/recipes/1/edit', {}, development_session
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Remove'
    assert_includes last_response.body, "value=\"Ham Sandwich\""
  end

  def test_edit_pantry_page
    get '/pantry/edit'
    assert_logged_in

    insert_test_data('test_data')

    get '/pantry/edit', {}, development_session
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'My Pantry'
    assert_includes last_response.body, 'value="avocado"'
  end

  def test_login_page
    get '/login'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Login'

    get '/login', {}, development_session
    assert_equal 302, last_response.status
    get last_response['Location']
    assert_includes last_response.body, 'Last Made'
  end

  def test_signup_page
    get '/signup'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Confirm Password:'

    get '/signup', {}, development_session
    assert_equal 302, last_response.status
    get last_response['Location']
    assert_includes last_response.body, 'Last Made'
  end

  def test_signup_retains_data_from_login_form
    post '/login', { signup: 'on', username: 'test', password: 'testing' }
    assert_equal 302, last_response.status
    get last_response['Location']
    assert_includes last_response.body, 'Confirm Password:'
    assert_includes last_response.body, "value=\"test\""
    assert_includes last_response.body, "value=\"testing\""
  end

  def test_signup
    query_result = db.exec("SELECT username FROM users WHERE username = 'test'").first
    assert_nil query_result

    post '/signup', { username: 'test', password: 'testing', confirm_password: 'testing' }
    assert_equal 302, last_response.status
    assert_equal 'Account created! You are now able to log in.', session[:success]
    get last_response['Location']
    assert_includes last_response.body, 'Login'
    query_result = db.exec("SELECT username FROM users WHERE username = 'test'").first['username']
    assert_equal 'test', query_result
  end

  def test_login
    insert_test_data('test_data')
    get '/login'
    assert_nil session[:success]
    assert_nil session[:username]
    assert_nil session[:user_id]

    post '/login', { username: 'development', password: 'verysecure' }
    assert_equal 302, last_response.status
    assert_equal 'Welcome!', session[:success]
    assert_equal 'development', session[:username]
    assert_equal '1', session[:user_id]
  end

  def test_invalid_login
    insert_test_data('test_data')
    post '/login', { username: 'development', password: 'wrongpassword' }
    assert_equal 401, last_response.status
    assert_includes last_response.body, 'Invalid credentials'

    post '/login', { username: 'wrongusername', password: 'verysecure' }
    assert_equal 401, last_response.status
    assert_includes last_response.body, 'Invalid credentials'

    post '/login', { username: 'notarealuser', password: 'wrongpassword' }
    assert_equal 401, last_response.status
    assert_includes last_response.body, 'Invalid credentials'
  end

  def test_logout
    get '/recipes?page=1', {}, development_session
    assert_equal 'development', session[:username]
    assert_equal '1', session[:user_id]

    post '/logout'
    assert_equal 302, last_response.status
    get last_response['Location']
    assert_includes last_response.body, 'Login'
    assert_nil session[:username]
    assert_nil session[:user_id]
  end

  def test_create_recipe
    insert_test_data('test_data')
    recipe_names = db.exec('SELECT name FROM recipes;').map { |tuple| tuple['name'] }
    refute_includes recipe_names, 'test'

    post '/recipes/new', { recipe_name: 'test' }, development_session
    assert_equal 302, last_response.status
    assert_equal '<strong>test</strong> was added to your recipe book.', session[:success]
    get last_response['Location']
    assert_includes last_response.body, 'Mark as Made'
    assert_includes last_response.body, 'test'
    recipe_names = db.exec('SELECT name FROM recipes;').map { |tuple| tuple['name'] }
    assert_includes recipe_names, 'test'
  end

  def test_editing_recipe_name
    params_hash = recipe_1_params_hash
    params_hash['recipe_name'] = 'test'

    insert_test_data('test_data')
    recipe_name = db.exec('SELECT name FROM recipes WHERE id = 1;').map { |tuple| tuple['name'] }.first
    assert_equal recipe_name, 'Ham Sandwich'

    post '/recipes/1', params_hash.merge({ cancel: 'on' }), development_session
    assert_equal 302, last_response.status
    get last_response['Location']
    assert_includes last_response.body, 'Mark as Made'
    assert_includes last_response.body, 'Ham Sandwich'
    recipe_name = db.exec('SELECT name FROM recipes WHERE id = 1;').map { |tuple| tuple['name'] }.first
    assert_equal recipe_name, 'Ham Sandwich'

    post '/recipes/1', params_hash, development_session
    assert_equal 302, last_response.status
    assert_equal "<strong>test</strong> updated successfully.", session[:success]
    get last_response['Location']
    assert_includes last_response.body, 'Mark as Made'
    assert_includes last_response.body, 'test'
    recipe_name = db.exec('SELECT name FROM recipes WHERE id = 1;').map { |tuple| tuple['name'] }.first
    assert_equal recipe_name, 'test'
  end

  def test_delete_recipe
    insert_test_data('test_data')
    recipe_name = db.exec('SELECT name FROM recipes WHERE id = 1;').map { |tuple| tuple['name'] }.first
    assert_equal recipe_name, 'Ham Sandwich'

    post '/recipes/1/delete', {}, development_session
    assert_equal 302, last_response.status
    assert_equal "Deleted <strong>Ham Sandwich</strong>", session[:success]
    get last_response['Location']
    assert_includes last_response.body, 'Last Made'
    recipe_name = db.exec('SELECT name FROM recipes WHERE id = 1;').map { |tuple| tuple['name'] }.first
    assert_nil recipe_name
  end

  def test_mark_recipe_made
    insert_test_data('test_data')
    recipe_date = db.exec('SELECT date_last_made FROM recipes WHERE id = 2;')
    recipe_date = recipe_date.map { |tuple| tuple['date_last_made'] }.first
    assert_equal '2023-05-01', recipe_date
    ingredient_amount = db.exec('SELECT amount_in_pantry FROM ingredients WHERE id = 2;')
    ingredient_amount = ingredient_amount.map { |tuple| tuple['amount_in_pantry'] }.first
    assert_equal '30/1', ingredient_amount
    ingredient_amount = db.exec('SELECT amount_in_pantry FROM ingredients WHERE id = 1;')
    ingredient_amount = ingredient_amount.map { |tuple| tuple['amount_in_pantry'] }.first
    assert_nil ingredient_amount

    post '/recipes/2/made', {}, development_session
    assert_equal 302, last_response.status
    assert_equal "<strong>Turkey Sandwich</strong> was marked as made today! "\
                      ' Its ingredients have been removed from your pantry.', session[:success]
    get last_response['Location']
    recipe_date = db.exec('SELECT date_last_made FROM recipes WHERE id = 2;')
    recipe_date = recipe_date.map { |tuple| tuple['date_last_made'] }.first
    assert_equal Date.today.to_s, recipe_date
    assert_includes last_response.body, Date.today.strftime('%B %d, %Y')
    ingredient_amount = db.exec('SELECT amount_in_pantry FROM ingredients WHERE id = 2;')
    ingredient_amount = ingredient_amount.map { |tuple| tuple['amount_in_pantry'] }.first
    assert_equal '28/1', ingredient_amount
    ingredient_amount = db.exec('SELECT amount_in_pantry FROM ingredients WHERE id = 1;')
    ingredient_amount = ingredient_amount.map { |tuple| tuple['amount_in_pantry'] }.first
    assert_nil ingredient_amount
  end

  def test_create_step_from_editing_recipe
    insert_test_data('test_data')
    params_hash = recipe_1_params_hash
    params_hash['1_new_step_direction'] = 'test1'
    params_hash['1_new_step_notes'] = 'test2'
    recipe_directions = db.exec('SELECT direction FROM recipe_steps WHERE recipe_id = 1;')
    recipe_directions = recipe_directions.map { |tuple| tuple['direction'] }
    recipe_notes = db.exec('SELECT notes FROM recipe_steps WHERE recipe_id = 1;')
    recipe_notes = recipe_notes.map { |tuple| tuple['notes'] }
    refute_includes recipe_directions, 'test1'
    refute_includes recipe_notes, 'test2'

    post 'recipes/1', params_hash, development_session
    assert_equal 302, last_response.status
    get last_response['Location']
    recipe_directions = db.exec('SELECT direction FROM recipe_steps WHERE recipe_id = 1;')
    recipe_directions = recipe_directions.map { |tuple| tuple['direction'] }
    recipe_notes = db.exec('SELECT notes FROM recipe_steps WHERE recipe_id = 1;')
    recipe_notes = recipe_notes.map { |tuple| tuple['notes'] }
    assert_includes recipe_directions, 'test1'
    assert_includes recipe_notes, 'test2'
    assert_includes last_response.body, 'test1'
    assert_includes last_response.body, 'test2'
  end

  def test_create_step_from_new_recipe
    insert_test_data('test_data')
    params_hash = { 'recipe_name' => 'test3', '1_new_step_direction' => 'test1', '1_new_step_notes' => 'test2' }

    post 'recipes/new', params_hash, development_session
    assert_equal 302, last_response.status
    get last_response['Location']
    recipe_directions = db.exec('SELECT direction FROM recipe_steps WHERE recipe_id = 8;')
    recipe_directions = recipe_directions.map { |tuple| tuple['direction'] }
    recipe_notes = db.exec('SELECT notes FROM recipe_steps WHERE recipe_id = 8;')
    recipe_notes = recipe_notes.map { |tuple| tuple['notes'] }
    assert_includes recipe_directions, 'test1'
    assert_includes recipe_notes, 'test2'
    assert_includes last_response.body, 'test1'
    assert_includes last_response.body, 'test2'
    assert_includes last_response.body, 'test3'
  end

  def test_editing_step
    insert_test_data('test_data')
    params_hash = recipe_1_params_hash
    params_hash['1_step_direction'] = 'test1'
    params_hash['1_step_notes'] = 'test2'
    recipe_directions = db.exec('SELECT direction FROM recipe_steps WHERE recipe_id = 1;')
    recipe_directions = recipe_directions.map { |tuple| tuple['direction'] }
    recipe_notes = db.exec('SELECT notes FROM recipe_steps WHERE recipe_id = 1;')
    recipe_notes = recipe_notes.map { |tuple| tuple['notes'] }
    refute_includes recipe_directions, 'test1'
    refute_includes recipe_notes, 'test2'
    assert_includes recipe_directions, 'Assemble sandwich'
    assert_includes recipe_notes, 'You should be able to figure it out.'

    post 'recipes/1', params_hash, development_session
    assert_equal 302, last_response.status
    get last_response['Location']
    recipe_directions = db.exec('SELECT direction FROM recipe_steps WHERE recipe_id = 1;')
    recipe_directions = recipe_directions.map { |tuple| tuple['direction'] }
    recipe_notes = db.exec('SELECT notes FROM recipe_steps WHERE recipe_id = 1;')
    recipe_notes = recipe_notes.map { |tuple| tuple['notes'] }
    assert_includes recipe_directions, 'test1'
    assert_includes recipe_notes, 'test2'
    refute_includes recipe_directions, 'Assemble sandwich'
    refute_includes recipe_notes, 'You should be able to figure it out.'
    assert_includes last_response.body, 'test1'
    assert_includes last_response.body, 'test2'
    refute_includes last_response.body, 'Assemble sandwich'
    refute_includes last_response.body, 'You should be able to figure it out.'
  end

  def test_deleting_step
    insert_test_data('test_data')
    params_hash = recipe_1_params_hash
    params_hash['1_step_delete'] = 'on'
    recipe_directions = db.exec('SELECT direction FROM recipe_steps WHERE recipe_id = 1;')
    recipe_directions = recipe_directions.map { |tuple| tuple['direction'] }
    recipe_notes = db.exec('SELECT notes FROM recipe_steps WHERE recipe_id = 1;')
    recipe_notes = recipe_notes.map { |tuple| tuple['notes'] }
    assert_includes recipe_directions, 'Assemble sandwich'
    assert_includes recipe_notes, 'You should be able to figure it out.'

    post 'recipes/1', params_hash, development_session
    assert_equal 302, last_response.status
    get last_response['Location']
    recipe_directions = db.exec('SELECT direction FROM recipe_steps WHERE recipe_id = 1;')
    recipe_directions = recipe_directions.map { |tuple| tuple['direction'] }
    recipe_notes = db.exec('SELECT notes FROM recipe_steps WHERE recipe_id = 1;')
    recipe_notes = recipe_notes.map { |tuple| tuple['notes'] }
    refute_includes recipe_directions, 'Assemble sandwich'
    refute_includes recipe_notes, 'You should be able to figure it out.'
    refute_includes last_response.body, 'Assemble sandwich'
    refute_includes last_response.body, 'You should be able to figure it out.'
  end

  def test_create_ingredient_from_editing_recipe
    insert_test_data('test_data')
    params_hash = recipe_1_params_hash
    params_hash['recipe_name'] = 'test1'
    params_hash['1_new_ingredient_name'] = 'test2'
    params_hash['1_new_ingredient_cost'] = '3'
    params_hash['1_new_ingredient_amount_in_recipe'] = '4'
    ingredient = db.exec('SELECT * FROM ingredients WHERE id = 11;').first
    assert_nil ingredient

    post 'recipes/1', params_hash, development_session
    assert_equal 302, last_response.status
    get last_response['Location']
    ingredient = db.exec('SELECT * FROM ingredients WHERE id = 11;').first
    ingredient_amount = db.exec('SELECT ingredient_amount FROM ingredients_recipes '\
                                'WHERE recipe_id = 1 AND ingredient_id = 11;').first
    assert_equal 'test2', ingredient['name'], 'test2'
    assert_equal '3.0', ingredient['cost']
    assert_equal '4/1', ingredient_amount['ingredient_amount']
    assert_includes last_response.body, 'test1'
    assert_includes last_response.body, 'test2'
    assert_includes last_response.body, '$12.00'
    assert_includes last_response.body, '4'
  end

  def test_create_ingredient_from_new_recipe
    insert_test_data('test_data')
    params_hash = { 'recipe_name' => 'test1', '1_new_ingredient_name' => 'test2',
                    '1_new_ingredient_cost' => '3', '1_new_ingredient_amount_in_recipe' => '4' }
    ingredient = db.exec('SELECT * FROM ingredients WHERE id = 11;').first
    assert_nil ingredient

    post 'recipes/new', params_hash, development_session
    assert_equal 302, last_response.status
    get last_response['Location']
    ingredient = db.exec('SELECT * FROM ingredients WHERE id = 11;').first
    ingredient_amount = db.exec('SELECT ingredient_amount FROM ingredients_recipes '\
                                'WHERE recipe_id = 8 AND ingredient_id = 11;').first
    assert_equal 'test2', ingredient['name'], 'test2'
    assert_equal '3.0', ingredient['cost']
    assert_equal '4/1', ingredient_amount['ingredient_amount']
    assert_includes last_response.body, 'test1'
    assert_includes last_response.body, 'test2'
    assert_includes last_response.body, '$12.00'
    assert_includes last_response.body, '4'
  end

  def test_create_ingredient_from_pantry
    insert_test_data('test_data')
    params_hash = pantry_params_hash
    params_hash['1_new_ingredient_name'] = 'test'
    params_hash['1_new_ingredient_cost'] = '3'
    params_hash['1_new_ingredient_amount_in_pantry'] = '4'
    params_hash['1_new_ingredient_number_per_purchase'] = '2'
    ingredient = db.exec('SELECT * FROM ingredients WHERE id = 11;').first
    assert_nil ingredient

    post '/pantry', params_hash, development_session
    assert_equal "Pantry updated successfully.", session[:success]
    assert_equal 302, last_response.status
    get last_response['Location']
    ingredient = db.exec('SELECT * FROM ingredients WHERE id = 11;').first
    assert_equal 'test', ingredient['name']
    assert_equal '1.5', ingredient['cost']
    assert_equal '4/1', ingredient['amount_in_pantry']
    assert_includes last_response.body, 'test'
    assert_includes last_response.body, '$1.50'
    assert_includes last_response.body, '4'
  end

  def test_edit_ingredient
    insert_test_data('test_data')
    params_hash = pantry_params_hash
    params_hash['1_ingredient_name'] = 'test'
    params_hash['1_ingredient_cost'] = '3'
    params_hash['1_ingredient_amount_in_pantry'] = '4'
    ingredient = db.exec('SELECT * FROM ingredients WHERE id = 1;').first
    assert_equal 'pack of sliced ham', ingredient['name']
    assert_equal '3.99', ingredient['cost']
    assert_nil ingredient['amount_in_pantry']

    post '/pantry', params_hash, development_session
    assert_equal 302, last_response.status
    get last_response['Location']
    ingredient = db.exec('SELECT * FROM ingredients WHERE id = 1;').first
    assert_equal 'test', ingredient['name']
    assert_equal '3.0', ingredient['cost']
    assert_equal '4/1', ingredient['amount_in_pantry']
    assert_includes last_response.body, 'test'
    assert_includes last_response.body, '$3.00'
    assert_includes last_response.body, '4'
  end

  def test_pair_ingredient_to_recipe
    insert_test_data('test_data')
    params_hash = recipe_1_params_hash
    params_hash['1_new_ingredient_name'] = 'pack of turkey'
    params_hash['1_new_ingredient_cost'] = ''
    pairing = db.exec('SELECT * FROM ingredients_recipes WHERE recipe_id = 1 AND ingredient_id = 4;').first
    assert_nil pairing
    ingredient = db.exec("SELECT name FROM ingredients WHERE name = 'pack of turkey';")
    assert_equal 1, ingredient.count

    post '/recipes/1', params_hash, development_session
    assert_equal 302, last_response.status
    get last_response['Location']
    pairing = db.exec('SELECT * FROM ingredients_recipes WHERE recipe_id = 1 AND ingredient_id = 4;').first
    refute_nil pairing
    ingredient = db.exec("SELECT name FROM ingredients WHERE name = 'pack of turkey';")
    assert_equal 1, ingredient.count

    assert_includes last_response.body, 'pack of turkey'
  end

  def test_unpair_ingredient_from_recipe
    insert_test_data('test_data')
    params_hash = recipe_1_params_hash
    params_hash['1_ingredient_unpair'] = 'on'
    pairing = db.exec('SELECT * FROM ingredients_recipes WHERE recipe_id = 1 AND ingredient_id = 1;').first
    refute_nil pairing
    ingredient = db.exec('SELECT * FROM ingredients WHERE id = 1;').first
    assert_equal 'pack of sliced ham', ingredient['name']
    assert_equal '3.99', ingredient['cost']
    assert_nil ingredient['amount_in_pantry']

    post '/recipes/1', params_hash, development_session
    assert_equal 302, last_response.status
    get last_response['Location']
    pairing = db.exec('SELECT * FROM ingredients_recipes WHERE recipe_id = 1 AND ingredient_id = 1;').first
    assert_nil pairing
    ingredient = db.exec('SELECT * FROM ingredients WHERE id = 1;').first
    assert_equal 'pack of sliced ham', ingredient['name']
    assert_equal '3.99', ingredient['cost']
    assert_nil ingredient['amount_in_pantry']

    refute_includes last_response.body, 'pack of sliced ham'
  end

  def test_delete_ingredient
    insert_test_data('test_data')
    params_hash = pantry_params_hash
    params_hash['1_ingredient_delete'] = 'on'
    ingredient = db.exec('SELECT * FROM ingredients WHERE id = 1;').first
    assert_equal 'pack of sliced ham', ingredient['name']
    assert_equal '3.99', ingredient['cost']
    assert_nil ingredient['amount_in_pantry']

    post '/pantry', params_hash, development_session
    assert_equal 302, last_response.status
    get last_response['Location']
    ingredient = db.exec('SELECT * FROM ingredients WHERE id = 1;').first
    assert_nil ingredient
    refute_includes last_response.body, 'pack of sliced ham'
  end

  def test_recipe_error
    insert_test_data('test_data')

    params_hash = { 'recipe_name' => '' }
    post 'recipes/new', params_hash, development_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Recipe names must be between 1 and 35 characters.'

    params_hash = { 'recipe_name' => 'a' * 36 }
    post 'recipes/new', params_hash
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Recipe names must be between 1 and 35 characters.'

    params_hash = { 'recipe_name' => 'Ham Sandwich' }
    post 'recipes/new', params_hash
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Recipe names must be unique.'

    params_hash = { 'recipe_name' => 'Ham Sandwich', '1_step_direction' => '', '1_step_notes' => '' }
    post 'recipes/1', params_hash
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Recipe directions must be between 1 and 100 characters.'

    params_hash = { 'recipe_name' => 'test', '1_new_step_direction' => ('a' * 101) }
    post 'recipes/new', params_hash
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Recipe directions must be between 1 and 100 characters.'

    params_hash = { 'recipe_name' => 'test', '1_new_step_notes' => 'test' }
    post 'recipes/new', params_hash
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Direction notes cannot be included without an associated direction.'
  end

  def test_ingredient_error
    insert_test_data('test_data')

    params_hash = pantry_params_hash
    params_hash['1_ingredient_name'] = ''
    params_hash['1_ingredient_cost'] = ''
    params_hash['1_ingredient_amount_in_pantry'] = ''
    post 'pantry', params_hash, development_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Ingredient names must be between 1 and 100 characters.'

    params_hash = { 'recipe_name' => 'Ham Sandwich', '1_new_ingredient_name' => 'slice of bread' }
    post 'recipes/1', params_hash
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Ingredient names must be unique.'

    params_hash = { 'recipe_name' => 'test', '1_new_ingredient_cost' => '1' }
    post 'recipes/new', params_hash
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'An ingredient cost cannot be included without an associated ingredient name.'

    params_hash = { 'recipe_name' => 'test', '1_new_ingredient_amount_in_recipe' => '1' }
    post 'recipes/new', params_hash
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'An ingredient amount cannot be included without an associated ingredient name.'

    params_hash = { 'recipe_name' => 'test', '1_new_ingredient_number_per_purchase' => '1' }
    post 'recipes/new', params_hash
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'An ingredient number per purchase cannot be included without an associated '\
                                        'ingredient name.'

    params_hash = { 'recipe_name' => 'test', '1_new_ingredient_name' => 'test', '1_new_ingredient_cost' => '~' }
    post 'recipes/new', params_hash
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Costs may only include numbers, up to one decimal point, and up to one '\
                                        'dollar sign.'

    params_hash = { 'recipe_name' => 'test', '1_new_ingredient_name' => 'test',
                    '1_new_ingredient_amount_in_recipe' => '~' }
    post 'recipes/new', params_hash
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Ingredient amounts must be written as decimals or fractions which include '\
                                        'numbers, up to one decimal point, and up to one forward slash.'
  end

  def test_signup_error
    insert_test_data('test_data')

    post '/signup', { username: 'test', password: 'testing', confirm_password: 'testing', cancel: 'on'}
    assert_equal 302, last_response.status
    get last_response['Location']
    assert_includes last_response.body, 'Login'

    post '/signup', { username: '', password: 'testing', confirm_password: 'testing' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please fill out all fields.'

    post '/signup', { username: 'development', password: 'testing', confirm_password: 'testing' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Sorry, that username is already taken.'

    post '/signup', { username: '~', password: 'testing', confirm_password: 'testing' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Usernames may only contain capital or lowercase letters, '\
                                      'numbers, and the following symbols: !, @, #, $, %, ^, &, or *'

    post '/signup', { username: 'test', password: '~', confirm_password: 'testing' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Passwords may only contain capital or lowercase letters, '\
                                      'numbers, and the following symbols: !, @, #, $, %, ^, &, or *'

    post '/signup', { username: 'test', password: 'testing', confirm_password: 'test' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'The provided passwords do not match.'
  end

  def test_mismatch_cost
    insert_test_data('test_data')
    params_hash = { 'recipe_name' => 'test', '1_new_ingredient_name' => 'slice of bread',
                    '1_new_ingredient_cost' => '100' }
    post '/recipes/new', params_hash, development_session
    assert_equal 302, last_response.status
    assert_equal '<strong>test</strong> was added to your recipe book.', session[:success]
    assert_equal "One or more added ingredients had a different listed cost than the ingredient's cost in your "\
                "pantry. They have defaulted to the cost listed in your pantry. To update the ingredients' "\
                'cost for all recipes, go to <a href="/pantry?in_stock_page=1&out_of_stock_page=1">your pantry</a>.',
                session[:error]
  end

  def test_recipe_list_sorting
    insert_test_data('test_data')
    get '/recipes?page=1', {}, development_session
    assert last_response.body.index('Avocado Toast') < last_response.body.index('Turkey Sandwich')
    assert last_response.body.index('Turkey Sandwich') < last_response.body.index('Eggs Over Easy')
    assert last_response.body.index('Eggs Over Easy') < last_response.body.index('Eggs Baked in Avocados')

    post '/recipes/5/made'
    get '/recipes?page=1'
    assert last_response.body.index('<h3>Turkey Sandwich</h3>') < last_response.body.index('<h3>Avocado Toast</h3>')

    post '/recipes/new', { recipe_name: 'aaa' }
    get '/recipes?page=1'
    assert last_response.body.index('<h3>aaa</h3>') < last_response.body.index('<h3>Eggs Over Easy</h3>')

    post '/recipes/new', { 'recipe_name' => 'bbb', '1_new_ingredient_name' => 'slice of bread',
                          '1_new_ingredient_cost' => '', '1_new_ingredient_amount_in_recipe' => ''}
    get '/recipes?page=1'
    assert last_response.body.index('<h3>bbb</h3>') < last_response.body.index('<h3>Turkey Sandwich</h3>')
  end

  def test_pantry_sorting
    insert_test_data('test_data')
    params_hash = pantry_params_hash
    params_hash['1_new_ingredient_name'] = 'aaa'
    params_hash['1_new_ingredient_amount_in_pantry'] = '4'
    params_hash['2_new_ingredient_name'] = 'aab'
    params_hash['3_new_ingredient_name'] = 'zzz'
    params_hash['3_new_ingredient_amount_in_pantry'] = '4'
    params_hash['4_new_ingredient_name'] = 'zzy'

    post '/pantry', params_hash, development_session
    assert_equal 302, last_response.status
    get last_response['Location']
    in_stock, out_of_stock = last_response.body.split('Out-of-Stock Ingredients')
    assert in_stock.index('aaa') < in_stock.index('slice of bread')
    assert in_stock.index('zzz') > in_stock.index('slice of bread')
    assert out_of_stock.index('aab') < out_of_stock.index('pack of sliced ham')
    assert out_of_stock.index('zzy') > out_of_stock.index('pack of sliced ham')
  end

  def test_step_notes_array
    insert_test_data('test_data')
    params_hash = { 'recipe_name' => 'test', '1_new_step_direction' => 'test', '1_new_step_notes' => 'test\ntest' }
    post '/recipes/new', params_hash, development_session
    assert_equal 302, last_response.status
    get last_response['Location']
    assert_includes last_response.body.gsub(' ', ''), "<ol>\n<h3>Directions</h3>\n<li>\n<p>test</p>\n<ul>\n<li>test"\
                                                      "</li>\n<li>test</li>\n</ul>\n</li>\n</ol>"
  end

  def test_recipe_cost
    insert_test_data('test_data')
    params_hash = { 'recipe_name' => 'test1', '1_new_ingredient_name' => 'test2',
                    '1_new_ingredient_cost' => '3', '1_new_ingredient_amount_in_recipe' => '4',
                    '2_new_ingredient_name' => 'pack of sliced ham', '2_new_ingredient_amount_in_recipe' => '1',
                    '3_new_ingredient_name' => 'test3', '3_new_ingredient_cost' => '100',
                    '4_new_ingredient_name' => 'test4', '4_new_ingredient_amount_in_recipe' => '100'}
    post 'recipes/new', params_hash, development_session
    assert_equal 302, last_response.status
    get '/recipes?page=1'
    assert_includes last_response.body, '$15.99'
  end
end