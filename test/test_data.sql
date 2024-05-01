DROP TABLE ingredients_recipes;
DROP TABLE recipe_steps;
DROP TABLE recipes;
DROP TABLE ingredients;
DROP TABLE users;


CREATE TABLE users (
  id serial PRIMARY KEY,
  username text NOT NULL UNIQUE,
  password text NOT NULL
);

CREATE TABLE recipes (
  id serial PRIMARY KEY,
  owning_user integer REFERENCES users (id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  date_last_made date
);

CREATE TABLE ingredients (
  id serial PRIMARY KEY,
  owning_user integer REFERENCES users (id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  cost numeric,
  amount_in_pantry text
);

CREATE TABLE ingredients_recipes (
  id serial PRIMARY KEY,
  recipe_id integer REFERENCES recipes (id) ON DELETE CASCADE NOT NULL,
  ingredient_id integer REFERENCES ingredients (id) ON DELETE CASCADE NOT NULL,
  ingredient_amount text,
  UNIQUE (recipe_id, ingredient_id)
);

CREATE TABLE recipe_steps (
  id serial PRIMARY KEY,
  recipe_id integer REFERENCES recipes (id) ON DELETE CASCADE NOT NULL,
  direction text NOT NULL,
  notes text
);


INSERT INTO users (username, password)
  VALUES ('development', '$2a$12$q2blzpJlvX.Idr/bJydrjeBN/V9GNhrzEeOtw1.6Akg/9gdY6zSoe'),
         ('admin',       '$2a$12$ECUr2jOo5ZqhrPydYH/E5uNeHhW7Aa3x2VUwL5r2wPHpOd1kFmB4O');

INSERT INTO recipes (owning_user, name, date_last_made)
  VALUES (1, 'Ham Sandwich',                       CURRENT_TIMESTAMP::date),
         (1, 'Turkey Sandwich',                    '2023-05-01'),
         (1, 'Eggs Over Easy',                     NULL),
         (1, 'Eggs Baked in Avocados',             '2022-12-29'),
         (1, 'Avocado Toast',                      '2023-04-29'),
         (1, 'Black Bean and Zucchini Enchiladas', '2023-04-29'),
         (2, 'Turkey Sandwich',                    '2023-04-27');

INSERT INTO ingredients (owning_user, name, cost, amount_in_pantry)
  VALUES (1, 'pack of sliced ham', 3.99, NULL),
         (1, 'slice of bread',     0.17, '30/1'),
         (1, 'jar of mayonnaise',  5.69, '1/1'),
         (1, 'pack of turkey',     4.99, '2/3'),
         (1, 'egg',                0.46, NULL),
         (1, 'avocado',            0.74, '4/1'),
         (2, 'bread',              3.72, NULL),
         (2, 'mayonnaise',         5.69, NULL),
         (2, 'lettuce',            1.88, NULL),
         (2, 'provolone',          NULL, NULL);

INSERT INTO ingredients_recipes (recipe_id, ingredient_id, ingredient_amount)
  VALUES (1, 1,  '1/5'),
         (1, 2,  '2/1'),
         (1, 3,  NULL),
         (2, 2,  '2/1'),
         (2, 3,  NULL),
         (2, 4,  '1/5'),
         (3, 5,  '2/1'),
         (4, 5,  '8/1'),
         (4, 6,  '4/1'),
         (5, 6,  '1/2'),
         (5, 2,  '1/10'),
         (7, 7,  NULL),
         (7, 8,  NULL),
         (7, 9,  NULL),
         (7, 10, NULL);

INSERT INTO recipe_steps (recipe_id, direction, notes)
  VALUES (1, 'Assemble sandwich', 'You should be able to figure it out.'),
         (2, 'Spread mayonnaise between bread slices', DEFAULT),
         (2, 'Place turkey between bread slices', DEFAULT),
         (3, 'Fry egg', DEFAULT),
         (4, 'Preheat oven to 450°F.', DEFAULT),
         (4, 'Halve each avocado and remove enough flesh to fit an egg.', DEFAULT),
         (4, 'Crack one egg into each avocado half.',
             'Don''t worry if some egg white spills out.\nDon''t throw away your ' ||
             'shells, there are plenty of things you can do with them!'),
         (4, 'Bake until egg whites are set.', 'Roughly 12 minutes'),
         (5, 'Toast bread', DEFAULT),
         (5, 'Halve avocado', DEFAULT),
         (5, 'Spread avocado on toast', DEFAULT),
         (7, 'Hello World', 'Goodbye World');