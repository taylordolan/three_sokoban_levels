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

  blueprint = make_blueprint(016)
  -- build the current level
  build_board(blueprint)
end

function _update60()

  if btnp(5) then
    edit_mode = not edit_mode
    build_board(blueprint)
  end

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
  else
    -- check if the current level is complete


    -- if level_complete then
      -- if there's another level, restart using the next level
      -- if current_level < #levels then
        -- current_level += 1
        -- _init()
      -- if there are no more levels, then don't accept input
      -- else
      --   return
      -- end
    -- check for button input and trigger movement
    -- else
    for i = 1, 4 do
      -- using `i - 1` because arrow key values are 0,1,2,3
      if btnp(i - 1) then
        -- this maps directions to button input values
        local dirs = {{-1,0},{1,0},{0,-1},{0,1}}
        -- move all heroes
        for next in all(heroes) do
          next:attempt_move(dirs[i])
        end
        for next in all(heroes) do
          next.pushed = false
        end
      end
    end
    -- end
  end
end

function _draw()
  -- level_complete = is_level_complete()
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
  -- function hero:attempt_move(dir)
    if self.pushed then
      -- self.pushed = false
      return
    end
    -- self.pushed = false
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
            thing.pushed = true
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
000000000000000077777770fffffff055555550eeeeeee0000000000000000000000000000000000000000077eeee7777eeee7777eeee7777eeee7777eeee77
000000000002000077777770fffffff055555550eee0eee000000000000000000000000000000000000000007777777777777777777777777777777777777777
000000000222220077777770fffffff055555550e00000e000000000000000000000000000000000000000005525555755755557557555575575555775555557
000000000002000077777770fffffff055555550eee0eee0000000000000000000000000000000000000000072ffff7772ffff272f7ff7f22f7ff7f22f7ff7f2
000000000020200077777770fffffff055555550ee0e0ee000000000000000000000000000000000000000005f5555f55f5555f55f5555f55f5555f55f5555f5
000000000020200077777770fffffff055555550ee0e0ee000000000000000000000000000000000000000005ffffff55ffffff55ffffff55ffffff55ffffff5
000000000000000077777770fffffff055555550eeeeeee0000000000000000000000000000000000000000052f5577552f5572552f5572552f5572552f55725
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000005527777555777775557777755577777555777775
77eeee77277777772f7f7ff77777777727f7f7f727f7f7f727777777777777777777777727777777777577777775777752577755777777777777777777eeee77
7777777777777777577f777777777775757575757575757577777777775f55577777757775f7555755525555555255555f775755777777777777777777777777
557555577777e7777755f57777777775f7f7f7f7f7f7f7f777777777775ffff775ffff7775f7fff7555f777e555f777e27575755ff5555755575555755755557
2ff77ff2777777777f577f77777277f5757575757575757577777f77775f577777f55f7775f77777555f5555777777225f775755ff5727752f75777227f7f7f2
5f5555f57777777777fff777777777f5f7f7f7f7f7f7f7f7777777f7777727f577f5ef7777777f5755577772e55f55555757f7f755555f555f5555f55f5555f5
5ffffff5777777777555757777777575757575757575757577777575777ffffe77f55f777fff7f57e77f5555555f75555555757552ffff5f5ffffff55ffffff5
27f55f727777e777757775f5777ff7e7f7f7f7f7f7f7f7f7757775fe777555f577fff25775557f57555f777755577777ee77777757f5775f52f577f552f577f5
55777775277777777577e777755555757575757e7575757e77777575777777777757777777777777777777777777777e555575755527755f5577752555777525
77577777777777777777777777777777777777777777777777777777277777777777777777777777775757775552555557525555777777777777777777727777
727777277277772775f7555775f7555775f7555775f7555775f7555775f7555775f7555775f2555777575777555f5555575f7555777777777777777775ff5557
777777777777777775f7fff775f7fff775f7fff775f7ffff75f7fff775f7fff775f7fff775f7fff7275257777277777e2f775555777555755775557575f7eff7
77777f7777777f7775f7777775f7777775fff77775fff77775f5575775fff75575fff75575fff75f5f5f7777555f5555575f7555777527777775777275f557f7
777777f7777777f777777f5777772f57772fff57772fff5577255f57777fff55777fff57777fff5f72775777555e77777277555555555f55f5555f557f755f57
77777575777775757fff2fe77fff7fe77fff7fe77fff7fe777777fe57fff7fe57fff7fe57fff7f7e5f5f777755577772575775552fffff57ffffff577fff7f57
757775fe7e7775e775557f5775557f5775557f5775557f5577777f5775557f5575557f5775552f5f27575777777f5555575755557f577f572f577f577555ff57
e777757577777575777777777777777777777777777777777777775777777755777777577777775f5f7777775557777755555555577752575777525777777777
575255555555255555755255777777777577f7577757f757777577757555557755557577555555555725557555555575755757777777777777eeee7777eeee77
575f75557555f75577777f55777777777577f5777752f55777257f75757ffff757fff5775725557557fffff552fffff52fff5777777777777777777775777757
2ff75555777775557777777e777777777572f5777755777777ff2f55752f555752f5757757fffff557f5557557f555757f575777777555755575555757755775
575f7555f555f75577f77f5577777777755577777775577777755777775777775577777757f55575557777775577777757777777777577722f7f77f22f7ff7f2
77775555777725557777727e7777777777f75777777277777777557777757777725777775577777572577777725777775577777755555f555f5555f55f5555f5
57577555f555775577f77755777777777772777777777777777777777772777777777777525777757777777777777777727777772fffff575ffffff55ffffff5
525755552555555555257f7e777777777757777777777777777777777777777777777777577777757777777777777777777777777f577f5752f577f552f55725
555555555555555555555755777777777777777777777777777777777777777777777777555ee555777ee777777ee77777777777577752575577752555777775
777277772f27777577eeee7700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
75fff557f2f777577777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
75f7eff72f2777775575555700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7ff557f7777757772ff77ff200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7f755ff7777577775f5555f500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7fff7f5777777e7e5ffffff500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
755fff57757777e727f55f7200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7777777757777e7e5577777500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

