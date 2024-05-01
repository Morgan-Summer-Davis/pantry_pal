# frozen_string_literal: false

require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'bcrypt'

# rubocop:disable Style/ExpandPathArguments
# - Reason: `File.expand_path(__dir__)` has undesirable edge cases
root = File.expand_path('..', __FILE__)
# rubocop:enable Style/ExpandPathArguments

require_relative "#{root}/recipe_data_structures"
require_relative "#{root}/db/database_manager"

configure do
  enable :sessions
  set :erb, escape_html: true
  set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
end

configure :development do
  require 'sinatra/reloader'
  also_reload "#{root}/db/database_manager.rb"
  also_reload "#{root}/db/recipe_manager.rb"
  also_reload "#{root}/db/ingredient_manager.rb"
  also_reload "#{root}/db/step_manager.rb"
  also_reload "#{root}/db/user_manager.rb"
  also_reload "#{root}/recipe_data_structures.rb"
end

# rubocop:disable Metrics/BlockLength
# - Reason: The helpers block is used internally by Sinatra and all methods used
#           inside views must be contained within it--therefore, the block will
#           naturally be much longer than blocks used for typical use cases.
helpers do
  def formatted_amount(amount)
    numerator    = amount.to_r.numerator
    denominator  = amount.to_r.denominator
    whole_number = numerator / denominator
    remainder    = (numerator.to_r.remainder(denominator.to_r) / denominator).to_r

    "#{whole_number} #{remainder}".chomp('/1').chomp(' 0').delete_prefix('0').strip
  end

  def deformatted_amount(formatted_amount)
    formatted_amount.squeeze(' ').strip.split.sum(&:to_r) if formatted_amount
  end

  def formatted_cost(value)
    "$#{format('%.2f', value)}" if value&.positive?
  end

  def formatted_amount_adjusted_cost(amount, cost)
    formatted_cost(cost * amount.to_r) if cost && amount
  end

  def available_ingredients(recipe)
    @recipes_metadata.find { |hash| hash[:id].to_i == recipe.id }[:amount_in_pantry].to_i
  end

  def total_ingredients(recipe)
    @recipes_metadata.find { |hash| hash[:id].to_i == recipe.id }[:amount_in_recipe].to_i
  end

  def recipe_cost(recipe)
    formatted_cost(@recipes_metadata.find { |hash| hash[:id].to_i == recipe.id }[:cost])
  end

  def recipe_class(recipe)
    case total_ingredients(recipe)
    when 0                             then 'incomplete_recipe'
    when available_ingredients(recipe) then 'ready_recipe'
    end
  end
end
# rubocop:enable Metrics/BlockLength

def check_user_logged_in
  return if session[:username]

  case env['PATH_INFO']
  when '/'                 then redirect '/login'
  when '/login', '/signup' then nil
  else
    session[:error] = 'You must be logged in to do that.'
    redirect '/login'
  end
end

def initialize_recipe_list_instance_variables
  @recipes_metadata = @storage.recipes_metadata
  @recipe_pages     = paginated_recipes
  @recipes          = @recipe_pages.flatten
  @page             = params[:page].to_i
end

def initialize_recipe_pagination_instance_variables
  @ingredient_pages = @ingredients.each_slice(10).to_a
  @ingredient_pages = [[]] if @ingredient_pages == []

  @step_pages       = @steps.each_slice(10).to_a
  @step_pages       = [[]] if @step_pages == []

  @i_page           = params[:ingredients_page].to_i
  @s_page           = params[:directions_page].to_i
end

def initialize_recipe_instance_variables(recipe_id)
  @recipes                 = @storage.all_user_recipes(session[:user_id])
  @recipe                  = @recipes.find { |recipe| recipe.id == recipe_id }

  initialize_recipe_step_and_ingredient_instance_variables(recipe_id)
  initialize_recipe_pagination_instance_variables
end

def initialize_recipe_step_and_ingredient_instance_variables(recipe_id)
  @in_stock, @out_of_stock = @storage.recipe_ingredients(recipe_id).partition do |ingredient|
    ingredient.amount_in_pantry.to_r >= ingredient.amount_in_recipe.to_r &&
      ingredient.amount_in_pantry&.positive?
  end

  @steps                   = @storage.recipe_steps(recipe_id)
  @ingredients             = @in_stock + @out_of_stock
end

def initialize_pantry_pagination_instance_variables
  @in_stock_pages          = @in_stock.each_slice(10).to_a
  @in_stock_pages          = [[]] if @in_stock == []
  @out_of_stock_pages      = @out_of_stock.each_slice(10).to_a
  @out_of_stock_pages      = [[]] if @out_of_stock == []

  @out_of_stock_page       = params[:out_of_stock_page].to_i
  @in_stock_page           = params[:in_stock_page].to_i
end

def initialize_pantry_instance_variables
  @ingredients             = @storage.all_user_ingredients(session[:user_id])
  @in_stock, @out_of_stock = @ingredients.partition { |ingredient| ingredient.amount_in_pantry&.positive? }

  initialize_pantry_pagination_instance_variables
end

def new_ingredients
  ingredients = params.select { |key, value| key.match?(/new_ingredient_name/) && value != '' }

  ingredients.map do |ingredient_key, _|
    ingredient_id = ingredient_key.split('_').first
    { name: params["#{ingredient_id}_new_ingredient_name"],
      cost: params["#{ingredient_id}_new_ingredient_cost"],
      amount_in_recipe: params["#{ingredient_id}_new_ingredient_amount_in_recipe"],
      amount_in_pantry: params["#{ingredient_id}_new_ingredient_amount_in_pantry"] }
  end
end

def adjust_ingredient_cost_with_number_per_purchase(ingredients)
  n_per_purchase = params.select { |key, _| key.match?(/new_ingredient_number_per_purchase/) }.map(&:last)

  ingredients.each_with_index do |ingredient, index|
    unless n_per_purchase[index].to_s.empty?
      ingredient[:cost] = (ingredient[:cost].to_r / n_per_purchase[index].to_r).to_f
    end
  end
end

def create_new_ingredients
  user_ingredients = @storage.all_user_ingredients(session[:user_id])
  ingredients_to_create = new_ingredients.reject do |ingredient|
    user_ingredients.map(&:name).include? ingredient[:name]
  end
  adjust_ingredient_cost_with_number_per_purchase(ingredients_to_create)

  @storage.create_ingredients(session[:user_id], *ingredients_to_create) if ingredients_to_create.count.positive?
end

def pair_new_ingredients
  return unless @recipe && new_ingredients.count.positive?

  @storage.pair_ingredients(@recipe.id, session[:user_id], *new_ingredients)
end

def new_steps
  steps = params.select { |key, value| key.match?(/new_step_direction/) && !value.empty? }

  steps.map.with_index do |_, index|
    { direction: params["#{index + 1}_new_step_direction"],
      notes: params["#{index + 1}_new_step_notes"],
      recipe_id: @recipe.id }
  end
end

def create_new_steps
  @storage.create_steps(*new_steps) if new_steps.count.positive?
end

def unpair_marked_ingredients
  ingredient_ids = params.select      { |key| key.match?(/ingredient_unpair/) }
  ingredient_ids = ingredient_ids.map { |key, _| key.split('_').first.to_i }

  ingredient_ids.each { |ingredient_id| @storage.unpair_ingredient(ingredient_id, @recipe.id) }
end

def delete_marked_ingredients
  ingredient_ids = params.select { |key| key.match?(/ingredient_delete/) }
  ingredient_ids = ingredient_ids.transform_keys! { |key| key.split('_').first.to_i }.keys

  @storage.delete_ingredients(*ingredient_ids) if ingredient_ids.count.positive?
end

def delete_marked_steps
  step_ids = params.select { |key| key.match?(/step_delete/) }
  step_ids = step_ids.transform_keys! { |key| key.split('_').first.to_i }.keys

  @storage.delete_steps(*step_ids) if step_ids.count.positive?
end

def update_edited_ingredients
  ingredients = updated_ingredients.reject { |ingredient| @ingredients.include? ingredient }
  @storage.update_ingredients(@recipe&.id, *ingredients)
end

def updated_ingredients
  @ingredients.map(&:deep_clone).map do |ingredient|
    parameters = params.select do |key, _|
      key.start_with?("#{ingredient.id}_ingredient_") && !key.match?(/(delete|unpair)/)
    end
    parameters.transform_keys! { |key| key.delete_prefix("#{ingredient.id}_ingredient_") }
    parameters.each { |key, value| ingredient.send("#{key}=", value) }

    ingredient
  end
end

def update_edited_steps
  steps = updated_steps.reject { |step| @steps.include? step }
  @storage.update_steps(*steps)
end

def updated_steps
  @steps.map(&:deep_clone).map do |step|
    step.direction = params["#{step.id}_step_direction"]
    step.notes     = params["#{step.id}_step_notes"]
    step
  end
end

def paginated_recipes
  recipes = @storage.all_user_recipes(session[:user_id])

  recipes = recipes.partition do |recipe|
    available_ingredients(recipe) == total_ingredients(recipe) && total_ingredients(recipe) != 0
  end
  recipes = recipes.flatten.each_slice(10).to_a
  recipes = [[]] if recipes == []

  recipes
end

# rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/AbcSize
# - Reason: Because these methods are almost entirely braching if expressions that lead to
#           string literals, the method length and cyclomatic complexity are off the
#           charts for all of them, despite being generally logically simple. By extension,
#           both perceived complexity and especially the branch portion of ABC complexity also
#           register as abnormally high. Trying to lower these to match the standards at
#           this point, in my opinion, would generally increase complexity.
def recipe_error
  recipes             = @storage.all_user_recipes(session[:user_id])
  recipe_name         = params[:recipe_name]

  directions          = params.select { |key, value| key.include?('direction') && !value.empty? }.values
  existing_directions = params.select { |key, _| key.include?('direction') && !key.include?('new') }.values
  notes               = params.select { |key, value| key.include?('notes') && !value.empty? }.values

  if !(1..35).cover? recipe_name.length
    'Recipe names must be between 1 and 35 characters.'
  elsif recipes.any? { |recipe| recipe.name == recipe_name && recipe != @recipe }
    'Recipe names must be unique.'
  elsif notes.count > directions.count
    'Direction notes cannot be included without an associated direction.'
  elsif existing_directions.any?(&:empty?) || directions.any? { |direction| direction.length > 100 }
    'Recipe directions must be between 1 and 100 characters.'
  else
    ingredient_error
  end
end

def ingredient_error
  names          = params.select { |key, value| key.include?('ingredient_name') && !value.empty? }.values
  existing_names = params.select { |key, _| key.include?('ingredient_name') && !key.include?('new') }.values
  n_per_purchase = params.select { |key, value| key.include?('number_per_purchase') && !value.empty? }
  costs          = params.select { |key, value| key.include?('cost') && !value.empty? }.values
  amounts        = params.select { |key, value| key.include?('amount') && !value.empty? }.values
  ingredients    = @recipe ? names + @ingredients&.map(&:name).to_a : names

  if ingredients != ingredients.uniq
    'Ingredient names must be unique.'
  elsif costs.count > ingredients.count
    'An ingredient cost cannot be included without an associated ingredient name.'
  elsif amounts.count > ingredients.count
    'An ingredient amount cannot be included without an associated ingredient name.'
  elsif n_per_purchase.count > names.difference(existing_names).count
    'An ingredient number per purchase cannot be included without an associated ingredient name.'
  elsif names.any? { |name| name.length > 100 } || existing_names.any?(&:empty?)
    'Ingredient names must be between 1 and 100 characters.'
  elsif costs.any? { |cost| cost.match?(/[^0-9.$]/) || cost.count('$') > 1 || cost.count('.') > 1 }
    'Costs may only include numbers, up to one decimal point, and up to one dollar sign.'
  # rubocop:disable Style/RegexpLiteral
  # - Reason: The complexity lost for not needing to escape the forward-slash here does not
  #           outweigh the complexity gained by not being able to use the space character
  #           in the regex to allow spaces and not other whitespace characters.
  elsif amounts.any? { |amount| amount.match?(/[^0-9.\/ ]/) || amount.count('./') > 1 }
    'Ingredient amounts must be written as decimals or fractions which include '\
    'numbers, up to one decimal point, and up to one forward slash.'
  end
  # rubocop:enable Style/RegexpLiteral
end

def signup_error
  username         = params[:username]
  password         = params[:password]
  confirm_password = params[:confirm_password]

  if username.empty? || password.empty? || confirm_password.empty?
    'Please fill out all fields.'
  elsif @storage.user_credentials(username)
    'Sorry, that username is already taken.'
  elsif username.match(/[^a-zA-Z0-9!@#%&$*\^]/)
    'Usernames may only contain capital or lowercase letters, numbers, and the '\
    'following symbols: !, @, #, $, %, ^, &, or *'
  elsif password.match(/[^a-zA-Z0-9!@#%&$*\^]/)
    'Passwords may only contain capital or lowercase letters, numbers, and the '\
    'following symbols: !, @, #, $, %, ^, &, or *'
  elsif password != confirm_password
    'The provided passwords do not match.'
  end
end

def mismatch_cost_notice
  all_ingredients = @storage.all_user_ingredients(session[:user_id])
  new_names       = params.select { |key| key.include?('new_ingredient_name') }.values
  new_costs       = params.select { |key| key.include?('new_ingredient_cost') }.values.map(&:to_f)

  return unless new_names.each_with_index.any? do |name, index|
    all_ingredients.map(&:name).include?(name) &&
    new_costs[index] != all_ingredients.find { |ingredient| ingredient.name == name }.cost &&
    !new_costs[index].zero?
  end

  'One or more added ingredients had a different listed cost than the '\
    "ingredient's cost in your pantry. They have defaulted to the cost listed in your "\
    "pantry. To update the ingredients' cost for all recipes, go to "\
    '<a href="/pantry?in_stock_page=1&out_of_stock_page=1">your pantry</a>.'
end
# rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/AbcSize

def valid_login?(username, password)
  valid_user = @storage.user_credentials(username)
  return false unless valid_user

  BCrypt::Password.new(valid_user[:password]) == password
end

def encrypt_password(password)
  BCrypt::Password.create(password)
end

def initialize_user_id
  user = @storage.user_credentials(session[:username])
  session[:user_id] = @storage.user_credentials(session[:username])[:id] if user
end

before do
  @storage ||= DatabaseManager.new(logger)
  check_user_logged_in
end

get '/' do
  redirect '/recipes?page=1'
end

get '/recipes' do
  initialize_recipe_list_instance_variables

  unless (1..@recipe_pages.count).cover? params[:page].to_i
    session[:error] = 'Page number out of range' unless params[:page].nil?
    status 404
    redirect '/recipes?page=1'
  end

  erb :recipes, layout: :layout
end

get '/recipes/new' do
  erb :new_recipe, layout: :layout
end

post '/recipes/new' do
  redirect '/recipes?page=1' if params[:cancel]

  error = recipe_error
  if error
    session[:error] = error
    status 422
    erb :new_recipe, layout: :layout
  else
    name            = params[:recipe_name]
    owning_user     = session[:user_id]
    session[:error] = mismatch_cost_notice

    @recipe = @storage.create_recipe(name, owning_user)

    create_new_ingredients
    pair_new_ingredients
    create_new_steps

    session[:success] = "<strong>#{@recipe.name}</strong> was added to your recipe book."
    redirect "/recipes/#{@recipe.id}?ingredients_page=1&directions_page=1"
  end
end

get '/recipes/:id' do
  initialize_recipe_instance_variables(params[:id].to_i)

  unless @recipes.map(&:id).include? params[:id].to_i
    session[:error] = 'Recipe not found'
    status 404
    redirect '/recipes?page=1'
  end

  unless (1..@ingredient_pages.count).cover?(params[:ingredients_page].to_i) &&
         (1..@step_pages.count).cover?(params[:directions_page].to_i)
    i_page = (1..@ingredient_pages.count).cover?(params[:ingredients_page].to_i) ? params[:ingredients_page] : 1
    d_page = (1..@step_pages.count).cover?(params[:directions_page].to_i) ? params[:directions_page] : 1

    session[:error] = 'Page number out of range' unless params[:ingredients_page].nil? && params[:directions_page].nil?
    status 404
    redirect "/recipes/#{params[:id]}?ingredients_page=#{i_page}&directions_page=#{d_page}"
  end

  erb :recipe, layout: :layout
end

get '/recipes/:id/edit' do
  initialize_recipe_instance_variables(params[:id].to_i)

  unless @recipes.map(&:id).include? params[:id].to_i
    session[:error] = 'Recipe not found'
    status 404
    redirect '/recipes?page=1'
  end
  erb :edit_recipe, layout: :layout
end

post '/recipes/:id' do
  redirect "/recipes/#{params[:id]}?ingredients_page=1&directions_page=1" if params[:cancel]

  initialize_recipe_instance_variables(params[:id].to_i)
  error = recipe_error
  if error
    session[:error] = error
    status 422
    erb :edit_recipe, layout: :layout
  else
    session[:error] = mismatch_cost_notice

    create_new_ingredients
    pair_new_ingredients
    update_edited_ingredients
    delete_marked_ingredients
    unpair_marked_ingredients
    create_new_steps
    update_edited_steps
    delete_marked_steps

    unless @recipe.name == params[:recipe_name].strip
      @recipe.name = params[:recipe_name]
      @storage.update_recipe(@recipe) if @recipe.name
    end

    session[:success] = "<strong>#{@recipe.name}</strong> updated successfully."
    redirect "/recipes/#{params[:id]}?ingredients_page=1&directions_page=1"
  end
end

post '/recipes/:id/made' do
  initialize_recipe_instance_variables(params[:id].to_i)
  @recipe.date_last_made = Date.today.to_s

  @ingredients.each do |ingredient|
    if ingredient.amount_in_pantry.to_r >= ingredient.amount_in_recipe.to_r
      ingredient.amount_in_pantry -= ingredient.amount_in_recipe.to_r
    end
  end

  session[:success] = "<strong>#{@recipe.name}</strong> was marked as made today! "\
                      ' Its ingredients have been removed from your pantry.'
  @storage.update_recipe(@recipe)
  @storage.update_ingredients(*@ingredients)
  redirect '/recipes?page=1'
end

post '/recipes/:id/delete' do
  recipe = @storage.get_recipe(params[:id])
  @storage.delete_recipe(params[:id])
  session[:success] = "Deleted <strong>#{recipe.name}</strong>"
  redirect '/recipes?page=1'
end

get '/pantry' do
  initialize_pantry_instance_variables
  unless (1..@out_of_stock_pages.count).cover?(params[:out_of_stock_page].to_i) &&
         (1..@in_stock_pages.count).cover?(params[:in_stock_page].to_i)
    o_page = (1..@out_of_stock_pages.count).cover?(params[:out_of_stock_page].to_i) ? params[:out_of_stock_page] : 1
    i_page = (1..@in_stock_pages.count).cover?(params[:in_stock_page].to_i) ? params[:in_stock_page] : 1

    session[:error] = 'Page number out of range' unless params[:out_of_stock_page].nil? && params[:in_stock_page].nil?
    status 404
    redirect "/pantry?in_stock_page=#{i_page}&out_of_stock_page=#{o_page}"
  end

  erb :pantry, layout: :layout
end

get '/pantry/edit' do
  initialize_pantry_instance_variables
  @out_of_stock.flatten!
  @in_stock.flatten!
  erb :edit_pantry, layout: :layout
end

post '/pantry' do
  redirect '/pantry?in_stock_page=1&out_of_stock_page=1' if params[:cancel]

  initialize_pantry_instance_variables
  error = ingredient_error
  if error
    session[:error] = error
    status 422
    erb :edit_pantry, layout: :layout
  else
    create_new_ingredients
    update_edited_ingredients
    delete_marked_ingredients
    unpair_marked_ingredients

    session[:success] = 'Pantry updated successfully.'
    redirect '/pantry?in_stock_page=1&out_of_stock_page=1'
  end
end

get '/login' do
  redirect '/recipes?page=1' if session[:username]

  erb :login, layout: :login_layout
end

post '/login' do
  redirect '/recipes?page=1' if session[:username]

  if params[:signup]
    session[:signup_username] = params[:username]
    session[:signup_password] = params[:password]
    redirect '/signup'
  end

  if !valid_login?(params[:username], params[:password])
    session[:error] = 'Invalid credentials'
    status 401
    erb :login, layout: :login_layout
  else
    session[:username] = params[:username]
    session[:user_id] = initialize_user_id
    session[:success] = 'Welcome!'
    redirect '/recipes?page=1'
  end
end

get '/signup' do
  redirect '/recipes?page=1' if session[:username]

  params[:username] ||= session[:signup_username]
  erb :signup, layout: :login_layout
end

post '/signup' do
  redirect '/login' if params[:cancel] || session[:username]

  error = signup_error
  if error
    session[:error] = error
    status 422
    erb :signup, layout: :login_layout
  else
    @storage.create_user(params[:username], encrypt_password(params[:password]))
    session[:success] = 'Account created! You are now able to log in.'
    redirect '/login'
  end
end

post '/logout' do
  redirect '/login' unless session[:username]

  session.delete(:username)
  session.delete(:user_id)
  session[:success] = "You've been signed out"
  redirect '/login'
end
