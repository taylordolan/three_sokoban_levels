pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- sokoban sketch
-- coyboy

-- todo
-- [ ] do some sort of mapping of types to sprites?
-- [ ] allow multiple adjacent heroes to move in the expected way

function _init()

	-- board size
	rows = 8
	cols = 8

  -- global stuff for play mode
  board = {}
  pieces = {}
  goals = {}
  heroes = {}
  level_complete = false

  -- global stuff for edit mode
  edit_mode = false
  cursor = {
    x = 1,
    y = 1,
    just_placed = false,
    piece_colors = {002, 005, 007, 014, 015},
    index = 1,
    attempt_move = function(self, dir)
      local dest = {self.x + dir[1], self.y + dir[2]}
      if tile_exists(dest) then
        self.x = dest[1]
        self.y = dest[2]
        self.just_placed = false
      end
    end,
    draw = function(self)
      rect(screen_x(self.x) - 2, screen_y(self.y) - 2, screen_x(self.x) + 8, screen_y(self.y) + 8, self.piece_colors[self.index])
      rect(screen_x(self.x) - 3, screen_y(self.y) - 3, screen_x(self.x) + 9, screen_y(self.y) + 9, 000)
    end,
  }

  blueprint = make_blueprint(008)
  -- build the current level
  build_board(blueprint)
end

function _update60()

  if btnp(5) then
    edit_mode = not edit_mode
    build_board(blueprint)
  end

  -- edit mode
  if edit_mode then
    if btnp(4) then
      if cursor.just_placed then
        cursor.index += 1
        if (cursor.index > #cursor.piece_colors) cursor.index = 1
      end
      blueprint[cursor.x][cursor.y] = cursor.piece_colors[cursor.index]
      cursor.just_placed = true
    else
      for i = 1, 4 do
        -- using `i - 1` because arrow key values are 0,1,2,3
        if btnp(i - 1) then
          -- this maps directions to button input values
          local dirs = {{-1,0},{1,0},{0,-1},{0,1}}
          cursor:attempt_move(dirs[i])
        end
      end
    end

  -- play mode
  else
    for i = 1, 4 do
      -- using `i - 1` because arrow key values are 0,1,2,3
      if btnp(i - 1) then
        -- this maps directions to button input values
        local dirs = {{-1,0},{1,0},{0,-1},{0,1}}
        -- move all heroes
        for next in all(heroes) do
          next:attempt_move(dirs[i], dirs[i])
        end
        for next in all(heroes) do
          next.moved_by_other = false
        end
      end
    end
  end
end

function _draw()
  -- clear the screen
  cls()
  -- draw the floor
  for x = 1, cols do
		for y = 1, rows do
			spr(002, screen_x(x), screen_y(y))
		end
	end
  if edit_mode then
    for x = 1, cols do
      for y = 1, rows do
        local foo = {
          [005] = 004,
          [015] = 003,
          [002] = 001,
          [014] = 005,
        }
        local color = blueprint[x][y]
        spr(foo[color], screen_x(x), screen_y(y))
      end
    cursor:draw()
    local message = "edit mode"
    print(message, 64 - #message * 2, 13, 007)
	end
  else
    -- draw things
    for next in all(pieces) do
      next:draw()
    end
    for next in all(goals) do
      next:draw()
    end
  end
end

function make_blueprint(level_sprite)

  -- draw the sprite at 1,1 instead of 0,0 so looping through
  -- rows and columns can also start at 1, as is the lua way
  spr(level_sprite, 1, 1)
  local level_table = {}

  for x = 1, cols do
		level_table[x] = {}
		for y = 1, rows do
      -- 2d array for the level
			level_table[x][y] = pget(x, y)
		end
	end
  return level_table
end

function build_board(level_table)

  -- maps colors in the level sprite to objects to generate
  color_mappings = {
    [005] = new_wall,
    [015] = new_block,
    [002] = new_hero,
    [014] = new_goal,
  }

  -- todo maybe kill this stuff
  board = {}
  pieces = {}
  goals = {}
  heroes = {}
  level_complete = false

  -- add stuff to the board
	for x = 1, cols do
		board[x] = {}
		for y = 1, rows do
      -- 2d array for the board
			board[x][y] = {}
      -- get the function in color_mappings that matches the
      -- current color in the level sprite
      local next = color_mappings[level_table[x][y]]
      -- set tiles for stuff from the level sprite
      if next then
        next():set_tile(x, y)
      end
		end
	end
end

-- checks to see if all goals are occupied by heroes
function is_level_complete()
  local complete = true
  for next in all(goals) do
    local content = tile_content({next.x, next.y})
    if not (content and content.sprite == 001) then
      complete = false
    end
  end
  return complete
end

-- using `piece` as a thing that goes on the board
function new_piece(sprite, fixed) -- fixed = can't be pushed
  local piece = {
    sprite = sprite,
    fixed = fixed,
    set_tile = function(self, x, y)
      -- remove it from its current tile, if it's in one
      if self.x and self.y then
        del(board[self.x][self.y], self)
      end
      -- set its x and y values
      self.x = x
      self.y = y
      -- put it in its new tile
      add(board[self.x][self.y], self)
    end,
    move = function(self, dir)
      local dest = {self.x + dir[1], self.y + dir[2]}
      -- if the tile exists and nothing is in the destination tile
      if tile_exists(dest) and tile_content(dest) == nil then
        self:set_tile(self.x + dir[1], self.y + dir[2])
      end
    end,
    draw = function(self)
      spr(self.sprite, screen_x(self.x), screen_y(self.y))
    end,
  }
  add(pieces, piece)
  return piece
end

function new_hero()
  local hero = new_piece(001, false)

  hero.attempt_move = function(self, dir)

    if self.moved_by_other then
      return
    end
    local next = {self.x, self.y}

    -- make a list of everything that can be moved
    local things_to_move = {}
    while true do
      if tile_exists(next) and tile_content(next) != nil then
        local thing = tile_content(next)
        -- if there's a wall, then nothing moves
        if thing.fixed then
          things_to_move = {}
          break
        else
          add(things_to_move, thing)
          if thing.sprite == 001 then
          end
        end
        next = {next[1] + dir[1], next[2] + dir[2]}
      else
        break
      end
    end

    -- attempt to move things, starting with the one that was
    -- furthest from the hero
    for j = #things_to_move, 1, -1 do
      things_to_move[j]:move(dir)
    end
  end

  add(heroes, hero)
  return hero
end

function new_goal()
  local goal = {
    sprite = 005,
    x = x,
    y = y,
  -- goal has a special set_tile because it doesn't get added to
  -- `board`. we need the goal's tile to technically be empty so
  -- the hero can step into it
    set_tile = function(self, x, y)
      self.x = x
      self.y = y
    end,
    draw = function(self)
      spr(self.sprite, screen_x(self.x), screen_y(self.y))
    end,
  }
  add(goals, goal)
  return goal
end

-- creates a wall
function new_wall()
  return new_piece(004, true)
end

-- creates a block
function new_block()
  return new_piece(003, false)
end

-- check if a tile actually exists on the board
function tile_exists(tile)
  return tile[1] >= 1 and tile[1] <= cols and tile[2] >= 1 and tile[2] <= rows
end

-- get the content of a tile
function tile_content(tile)
  -- tiles should only have 1 thing in them at a time for now
  return board[tile[1]][tile[2]][1]
end

-- get x screen position from x board position
function screen_x(x)
  local offset = 64 - cols * 4
  return (x - 1) * 8 + offset
end

-- get y screen position from y board position
function screen_y(y)
  local offset = 64 - rows * 4
  return (y - 1) * 8 + offset
end

-- delete by index, keeps order
-- thanks @ultrabrite
function idel(t, i)
  local n = #t
  if (i > 0 and i <= n) then
    for j = i, n - 1 do
      t[j] = t[j + 1]
    end
    t[n] = nil
  end
end

__gfx__
000000000000000077777770fffffff055555550eeeeeee0777277772f27777577eeee7700000000000000000000000000000000000000000000000000000000
000000000002000077777770fffffff055555550eee0eee075fff557f2f777577777777700000000000000000000000000000000000000000000000000000000
007007000222220077777770fffffff055555550e00000e075f7eff72f2777775575555700000000000000000000000000000000000000000000000000000000
000770000002000077777770fffffff055555550eee0eee07ff557f7777757772ff77ff200000000000000000000000000000000000000000000000000000000
000770000020200077777770fffffff055555550ee0e0ee07f755ff7777577775f5555f500000000000000000000000000000000000000000000000000000000
007007000020200077777770fffffff055555550ee0e0ee07fff7f5777777e7e5ffffff500000000000000000000000000000000000000000000000000000000
000000000000000077777770fffffff055555550eeeeeee0755fff57757777e727f55f7200000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000007777777757777e7e5577777500000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077727770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777072222270777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077727770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077272770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077272770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000007777777077777770777777707777777077777770eeeeeee0777777707777777000000000000000000000000000000000
000000000000000000000000000000007777777077777770777777707777777077777770eee7eee0777777707777777000000000000000000000000000000000
000000000000000000000000000000007777777077777770777777707777777077777770e77777e0777777707777777000000000000000000000000000000000
000000000000000000000000000000007777777077777770777777707777777077777770eee7eee0777777707777777000000000000000000000000000000000
000000000000000000000000000000007777777077777770777777707777777077777770ee7e7ee0777777707777777000000000000000000000000000000000
000000000000000000000000000000007777777077777770777777707777777077777770ee7e7ee0777777707777777000000000000000000000000000000000
000000000000000000000000000000007777777077777770777777707777777077777770eeeeeee0777777707777777000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000777777707777777077777770777777707777777077777770777777707777777000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

