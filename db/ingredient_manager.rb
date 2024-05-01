# frozen_string_literal: false

# # Provides methods to the database manager for managing ingredients, including
# fetching, creating, deleting, and updating them.
module IngredientManager
  require_relative '../recipe_data_structures'

  def all_user_ingredients(user)
    query_result = query(<<~SQL,
      SELECT * FROM ingredients
        WHERE owning_user = $1
        ORDER BY name ASC
    SQL
                         user)

    query_result.map do |tuple|
      tuple_to_ingredient(tuple)
    end
  end

  def find_ingredient(user_id, ingredient_name)
    all_user_ingredients(user_id).find { |user_ingredient| user_ingredient.name == ingredient_name }
  end

  def create_ingredients(owning_user, *ingredients)
    parameters = ingredients.map do |tuple|
      ingredient = tuple_to_ingredient(tuple)
      [owning_user, ingredient.name, ingredient.cost, ingredient.amount_in_pantry]
    end
    parameters.flatten!

    sql = 'INSERT INTO ingredients (owning_user, name, cost, amount_in_pantry) VALUES '
    1.step(parameters.count, 4) { |num| sql << "($#{num}, $#{num + 1}, $#{num + 2}, $#{num + 3}), " }

    query(sql.chomp(', '), *parameters)
  end

  def pair_ingredients(recipe_id, user_id, *ingredient_tuples)
    parameters = ingredient_tuples.map do |tuple|
      [recipe_id,
       find_ingredient(user_id, tuple[:name]).id,
       tuple[:amount_in_recipe].to_r]
    end
    parameters.flatten!

    sql = 'INSERT INTO ingredients_recipes (recipe_id, ingredient_id, ingredient_amount) VALUES '
    1.step(parameters.count, 3) { |num| sql << "($#{num}, $#{num + 1}, $#{num + 2}), " }

    query(sql.chomp(', '), *parameters)
  end

  def unpair_ingredient(ingredient_id, recipe_id)
    query('DELETE FROM ingredients_recipes WHERE recipe_id = $1 AND ingredient_id = $2',
          recipe_id, ingredient_id)
  end

  def update_ingredient(ingredient, recipe_id = nil)
    query('UPDATE ingredients SET name = $1, cost = $2, amount_in_pantry = $3 WHERE id = $4;',
          ingredient.name, ingredient.cost, ingredient.amount_in_pantry&.to_s, ingredient.id)

    return unless recipe_id

    query('UPDATE ingredients_recipes SET ingredient_amount = $1 WHERE recipe_id = $2 '\
          'AND ingredient_id = $3', ingredient.amount_in_recipe&.to_s, recipe_id, ingredient.id)
  end

  def update_ingredients(*args)
    recipe_id = args.shift unless args.first.instance_of?(RecipeDataStructures::Ingredient)

    args.each { |ingredient| update_ingredient(ingredient, recipe_id) }
  end

  def delete_ingredients(*ingredient_ids)
    sql = 'DELETE FROM ingredients WHERE '
    ingredient_ids.each_with_index { |_, index| sql << "id = $#{index + 1} OR " }

    query(sql.chomp('OR '), *ingredient_ids)
  end

  def recipe_ingredients(recipe_id)
    query_result = query(<<~SQL,
      SELECT i.*, ir.ingredient_amount AS amount_in_recipe
      	FROM recipes AS r
      	INNER JOIN ingredients_recipes AS ir ON r.id = ir.recipe_id
      	INNER JOIN ingredients AS i ON i.id = ir.ingredient_id
      	WHERE r.id = $1
      	ORDER BY ir.id ASC;
    SQL
                         recipe_id)

    query_result.map { |tuple| tuple_to_ingredient(tuple) }
  end

  private

  def tuple_to_ingredient(tuple)
    RecipeDataStructures::Ingredient.new(tuple[:id],               tuple[:owning_user],
                                         tuple[:name],             tuple[:cost],
                                         tuple[:amount_in_pantry], tuple[:amount_in_recipe])
  end
end
