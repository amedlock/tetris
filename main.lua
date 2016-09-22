require( "util" ) 
require( "vectors" )

local font = nil

local spriteData = nil
local spriteImage = nil
local sprites = List()

local gameMode = nil -- start, play, stop
local message = nil

local messages = { start='Tetris - Press any key to start', stop='Game Over - Press any key to restart' }

local screen = {}
local piece = nil
local board = nil

local score = 0
local stage = 1
local rowsToAdvance = 7
local stageSpeed = 0.5


local blockScale = 20/84

function calcStageSpeed(stageNum)
  local spd = 0.5
  if stageNum > 1 then spd = 0.5 - ( stageNum * 0.1 ) end
  if spd < 0.15 then spd = 0.15 end
  return spd
end


function increaseScore()
  score = score + ( 10 * stage )
  rowsToAdvance = rowsToAdvance - 1
  if rowsToAdvance <=0 then
    stage = stage + 1
    rowsToAdvance = 7 + (stage * 2 )  -- completely arbitrary
    stageSpeed = calcStageSpeed( stageSpeed )
  end
end

Cell = class("Cell")
function Cell:initialize( p, color )
  self.pos = vec(p.x,p.y)
  self.color = color
end

Board = class("Board")

function Board:initialize( w,h )
  self.width = w
  self.height = h
  self.grid = List()
end

function Board:valid( v )  return v.x > 0 and v.x <= self.width and v.y > 0 and v.y <= self.height end

function Board:solid( v )
  return self.grid:any( function(c) return c.pos==v end );
end

function Board:rowFilled( r )
  return self.grid:count( function(v) return v.pos.y==r end ) >= self.width
end

function Board:dropRow( r )
  self.grid = self.grid:filter( function(c) return c.pos.y~=r end )
  self.grid:each( function(c) if c.pos.y<r then c.pos = c.pos + vec(0,1) end end )
end

function Board:dropRows()
  local dropped = 0
  iterate( self.height, 1, function( row ) 
    if self:rowFilled(row) then
      self:dropRow( row )
      dropped = dropped + 1
      increaseScore()
    end  
  end)
  if dropped > 0 then self:dropRows() end
end

function resetGame()
  board.grid = List()
  score = 0
  stage = 1
  rowsToAdvance = 7
  stageSpeed = calcStageSpeed(stage)
  piece = createPiece() 
  gameMode = 'play'
end


Piece = class("Piece")

function Piece:initialize( pos, offsets, col )
  self.pos = pos
  self.offsets = List(offsets)
  self.color = col
end

function Piece:rotate()
  local rotated = List(self.offsets):collect( function(v) return vec( -v.y, v.x ) end )
  
  -- a constraint problem : find a nearby position in which the rotated piece does not hit walls or other pieces
  local p2 = nil
  for _, xoff in ipairs{ 0, -1, 1} do
    p2 = Piece( self.pos + vec( xoff, 0 ), rotated, self.color )
    if not p2:blocked() then break end
  end
  if not p2:blocked() then piece = p2 end
end

function Piece:blocked()
  return self.offsets:any( function( p ) 
    local f = p + self.pos
    return ( not board:valid(f) ) or board:solid( f )
  end )
end

function Piece:invalid( )
  return self.offsets:any( function(v) return board:invalid( self.pos + v ) end )
end

function Piece:move( x, y )
  local d = vec(x,y)
  local count =  self.offsets:count( function(v) 
    local coord = v + d + self.pos
    return (not board:valid( coord ) ) or board:solid(coord) 
  end )
  if count > 0 then return false end
  self.pos = self.pos + d  
  return true
end

function love.load()
  font = love.graphics.newFont( "arialbd.ttf", 24)
  love.graphics.setFont(font)
  
  spriteData = love.image.newImageData( "sprite_map.png" )
  spriteImage = love.graphics.newImage(  spriteData )
  local iw = spriteImage:getWidth()
  local ih = spriteImage:getHeight()
  
  iterate( 0, 5, function( xp ) 
    local x = ( xp *84 ) + xp
    local q = love.graphics.newQuad( x, 0, 84, 84, iw, ih )
    sprites:append( q )
  end )
  
  screen.width = love.graphics.getWidth()
  screen.height = love.graphics.getHeight()
  board = Board(10, 24)
  
  gameMode = 'start'
end

local shapes = {
  { vec(0,0), vec(0,1), vec(0,2), vec(0,3) }, -- straight piece
  { vec(0,0), vec(1,0), vec(0,1), vec(0,2) }, -- right corner
  { vec(0,0), vec(1,0), vec(1,1), vec(1,2) }, -- left corner
  { vec(-1,0), vec(0,0), vec(1,0), vec(0,1), vec(0,2) }, -- T piece
  { vec(0,0), vec(1,0), vec(1,1), vec(0,1)} -- square block
  };

function Board:store(p)
  local cells = p.offsets:collect( function(off) return Cell( off + p.pos, p.color ) end )
  cells:each( function(c) self.grid:append(c) end )
  piece = nil
end

function createPiece()
  local off = List( shapes[ math.random(1,5) ] )
  local col = math.random(1,6)  
  local pos = vec(2,1)
  
  while off:any( function(v) return board:solid( v + pos ) end ) do
    pos.x = pos.x + 1
    if pos.x >= board.width then return nil end
  end
  return Piece( pos, off, col )
end


function drawBlock( v, c )
  local b = vec( v.x - 1, v.y - 1 ):scale( 20 )
  local sp = vec(100,0) + b
  love.graphics.drawq(spriteImage, sprites[c], sp.x, sp.y,0, blockScale,blockScale )
end

function drawBoard()
  board.grid:each( function(c) drawBlock( c.pos, c.color ) end )
end


function drawPiece()
  if piece then
    piece.offsets:each( function( off ) drawBlock( piece.pos + off, piece.color ) end )
  end
end


function drawUI()
    love.graphics.setColor( 255,255,255,255 )
    local ty = screen.height - ( font:getHeight() + 6 )
    love.graphics.print( string.format("Score:%d Level:%d", score,stage ), 20, ty )
    local msg2 = "Press F10 to exit, F12 to restart"
    local tsize = font:getWidth( msg2 ) + 15
    love.graphics.print( msg2, screen.width - tsize, ty )
    love.graphics.rectangle( "line", 99,0, 20 * board.width, 20 * board.height )
end

function drawMenu()
  local msg = messages[ gameMode ]
  if not msg then return end
  
  if not font then return end
  local margin = 20
  
  love.graphics.setColor( 255,255,255,255 )
  local tw = font:getWidth( msg )
  local th = font:getHeight()
  local left = ( screen.width /2 ) - ( tw/ 2 )
  local top  = ( screen.height / 2 ) - ( th / 2 )
  love.graphics.print( msg, left , top )
  love.graphics.rectangle( "line", left - (margin/2), top - (margin/2), tw + margin, th + margin )
end

function love.draw() 
  if gameMode=='play' or gameMode=='stop' then
    drawBoard()
    drawPiece()
    drawUI()
  end
  if gameMode=='stop' or gameMode=='start' then
    drawMenu()
  end
end


function love.keypressed( k, u )
  if k=="f10" then 
    love.event.push("quit") 
  end
  
  if gameMode=='start' then
    resetGame()
    return
  elseif gameMode=='stop' then
    gameMode = 'start'
    return
  end
  
  if k=="f12" then
    piece = nil
    gameMode = 'stop'
    return
  end
  
  if piece ~= nil then
    if k=="left" then piece:move( -1, 0 )
    elseif k=="right" then piece:move(1,0) 
    elseif k=="up" then piece:rotate() 
    elseif k=="down" then piece:move(0,1) end
  end
end

function love.mousepressed( mx,my,b )
end
  
function love.mousereleased( x,y,b )
end

function love.keyreleased( k )
end



local timeCheck = 0

function love.update(dt)
  if not piece then return end

  timeCheck = timeCheck + dt
  if timeCheck > stageSpeed then
    timeCheck = timeCheck - stageSpeed;
    local moved = piece:move(0,1)
    if not moved then 
      board:store(piece)
      piece = createPiece()
      if piece==nil then gameMode='stop' end
      board:dropRows()    
    end
  end  
end


