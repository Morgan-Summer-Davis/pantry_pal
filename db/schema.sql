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