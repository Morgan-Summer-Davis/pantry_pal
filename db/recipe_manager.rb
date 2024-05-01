# frozen_string_literal: true

# # Provides methods to the database manager for managing recipes, including
# fetching, creating, deleting, and updating them.
module RecipeManager
  require 'date'

  require_relative '../recipe_data_structures'

  def all_user_recipes(user)
    query_result = query(<<~SQL,
      SELECT * FROM recipes
        WHERE owning_user = $1
        ORDER BY date_last_made ASC NULLS FIRST, name;
    SQL
                         user)

    query_result.map do |tuple|
      tuple_to_recipe(tuple)
    end
  end

  def get_recipe(recipe_id)
    tuple = query('SELECT * FROM recipes WHERE recipes.id = $1;', recipe_id).first

    tuple_to_recipe(tuple) if tuple
  end

  # rubocop:disable Metrics/MethodLength
  # - Reason: Most method length here is simply a string literal representing a
  #           complex SQL query. It could be condensed to fewer lines, but doing
  #           so would sacrifice readability.
  def recipes_metadata
    query_result = query(<<~SQL
      SELECT r.id,
             COUNT(i.amount_in_pantry) AS amount_in_pantry,
             COUNT(ir.recipe_id) AS amount_in_recipe,
             STRING_AGG(COALESCE(i.cost::text, '0'), ' ') AS ingredient_costs,
  	         STRING_AGG(COALESCE(ir.ingredient_amount, '0/1'), ' ') AS ingredient_amounts
      	FROM recipes AS r
      	FULL OUTER JOIN ingredients_recipes AS ir ON r.id = ir.recipe_id
      	FULL OUTER JOIN ingredients AS i ON i.id = ir.ingredient_id
  	    GROUP BY r.id
  	    ORDER BY r.id ASC;
    SQL
                        )

    query_result.each do |result|
      costs    = result[:ingredient_costs].split.map(&:to_r)
      amounts  = result[:ingredient_amounts].split.map(&:to_r)
      products = costs.zip(amounts).map { |arr| arr.inject(:*) }

      result[:cost] = products.sum
    end

    query_result
  end
  # rubocop:enable Metrics/MethodLength

  def update_recipe(recipe)
    query('UPDATE recipes SET name = $1, date_last_made = $2 WHERE id = $3;',
          recipe.name, recipe.date_last_made, recipe.id)
  end

  def create_recipe(name, owning_user)
    query('INSERT INTO recipes (owning_user, name) VALUES ($1, $2)', owning_user, name)

    tuple_to_recipe(query(<<~SQL
      SELECT * FROM recipes
        WHERE id IN
        ( SELECT MAX(id)
            FROM recipes );
    SQL
                         ).first)
  end

  def delete_recipe(recipe_id)
    query('DELETE FROM recipes WHERE id = $1', recipe_id)
  end

  private

  def tuple_to_recipe(tuple)
    RecipeDataStructures::Recipe.new(tuple[:id],   tuple[:owning_user],
                                     tuple[:name], tuple[:date_last_made])
  end
end
