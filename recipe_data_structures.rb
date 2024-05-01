# frozen_string_literal: true

module RecipeDataStructures
  # Parent class for all custom data classes for the recipe book app. Provides
  # functionality necessary for all objects--namely methods for comparison between
  # objects of the same class.
  class RecipeDataStructure
    def ==(other)
      return false if other.class != self.class

      vars = instance_variables.map { |var| var.to_s[1..] }
      vars.all? { |var| send(var) == other.send(var) }
    end

    def deep_clone(*params)
      self.class.new(*params)
    end
  end

  # Manages recipe objects. Primarily for verifying and formatting data related to recipes.
  class Recipe < RecipeDataStructure
    attr_reader :id, :owning_user, :name, :date_last_made

    # rubocop:disable Lint/MissingSuper
    def initialize(id, owning_user, name, date_last_made)
      @id                 = id.to_i
      @owning_user        = owning_user.to_i
      self.name           = name
      self.date_last_made = date_last_made
    end
    # rubocop:enable Lint/MissingSuper

    def name=(value)
      @name = value.strip
    end

    def date_last_made=(value)
      @date_last_made = (value ? Date.parse(value).strftime('%B %d, %Y') : nil)
    end

    def deep_clone
      super(id, owning_user, name, date_last_made)
    end
  end

  # Manages ingredient objects. Primarily for verifying and formatting data related to ingredients.
  class Ingredient < RecipeDataStructure
    attr_reader :id, :owning_user, :name, :cost, :amount_in_pantry, :amount_in_recipe

    # rubocop:disable Lint/MissingSuper, Metrics/ParameterLists
    def initialize(id, owning_user, name, cost, amount_in_pantry, amount_in_recipe = nil)
      @id                   = id.to_i
      @owning_user          = owning_user.to_i
      self.name             = name
      self.cost             = cost
      self.amount_in_pantry = amount_in_pantry
      self.amount_in_recipe = amount_in_recipe
    end
    # rubocop:enable Lint/MissingSuper, Metrics/ParameterLists

    def name=(value)
      @name = value.strip
    end

    def cost=(value)
      value = value.to_s.gsub(/[^0-9.]/, '') if value
      @cost = (value.to_r.zero? ? nil : value.to_f)
    end

    def amount_in_pantry=(value)
      @amount_in_pantry = value.to_r.zero? ? nil : value.to_r
    end

    def amount_in_recipe=(value)
      @amount_in_recipe = value.to_r.zero? ? nil : value.to_r
    end

    def deep_clone
      super(id, owning_user, name, cost, amount_in_pantry, amount_in_recipe)
    end
  end

  # Manages recipe step objects. Primarily for verifying and formatting data related to steps.
  class Step < RecipeDataStructure
    attr_reader :id, :recipe_id, :direction, :notes

    # rubocop:disable Lint/MissingSuper
    def initialize(id, recipe_id, direction, notes)
      @id            = id.to_i
      @recipe_id     = recipe_id.to_i
      self.direction = direction
      self.notes     = notes
    end
    # rubocop:enable Lint/MissingSuper

    def direction=(value)
      @direction = value.strip
    end

    def notes=(value)
      value = nil if value == ''
      @notes = value&.strip
    end

    def notes_array
      @notes ? @notes.split('\n') : []
    end

    def deep_clone
      super(id, recipe_id, direction, notes)
    end
  end
end
