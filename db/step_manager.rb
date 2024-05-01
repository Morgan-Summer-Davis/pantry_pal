# frozen_string_literal: false

# Provides methods to the database manager for managing recipe steps, including
# fetching, creating, deleting, and updating them.
module StepManager
  require_relative '../recipe_data_structures'

  def create_steps(*steps)
    parameters = steps.map do |hash|
      step = tuple_to_step(hash)
      [step.recipe_id, step.direction, step.notes]
    end
    parameters.flatten!

    sql = 'INSERT INTO recipe_steps (recipe_id, direction, notes) VALUES '
    1.step(parameters.count, 3) { |num| sql << "($#{num}, $#{num + 1}, $#{num + 2}), " }

    query(sql.chomp(', '), *parameters)
  end

  def delete_steps(*step_ids)
    # rubocop:disable Style/StringConcatenation
    # - Reason: Because of the interpolation within the block, interpolated the
    #           whole expression would involve nested interpolation. In this case,
    #           I find concatenation to be the much more readable option.
    sql = 'DELETE FROM recipe_steps WHERE ' +
          step_ids.map.with_index { |_, index| "id = $#{index + 1}" }.join(' OR ')
    # rubocop:enable Style/StringConcatenation

    query(sql, *step_ids)
  end

  def update_step(step)
    query('UPDATE recipe_steps SET direction = $1, notes = $2 WHERE id = $3;',
          step.direction, step.notes, step.id)
  end

  def update_steps(*steps)
    steps.each { |step| update_step(step) }
  end

  def recipe_steps(recipe_id)
    query_result = query(<<~SQL,
      SELECT rs.*
        FROM recipes AS r
        INNER JOIN recipe_steps AS rs ON r.id = rs.recipe_id
        WHERE r.id = $1
        ORDER BY rs.id ASC;
    SQL
                         recipe_id)

    query_result.map { |tuple| tuple_to_step(tuple) }
  end

  private

  def tuple_to_step(tuple)
    RecipeDataStructures::Step.new(tuple[:id],        tuple[:recipe_id],
                                   tuple[:direction], tuple[:notes])
  end
end
