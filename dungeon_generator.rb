require 'pickable'

$merged_graphs = []
$merged_rooms = []

class Grid
  include Enumerable, Pickable
  def initialize(w,h)
    @width, @height = w,h
    @entries = Array.new(w) {Array.new(h)}
  end
  def [](x,y)
    if x.between?(0,@width-1) && y.between?(0,@height-1)
      @entries[x][y]
    else
      nil
    end
  end
  def <<(s)
    x, y = s.x, s.y
    if x.between?(0,@width-1) && y.between?(0,@height-1)
      @entries[x][y] = s
    else
      raise RangeError
    end
  end
  
  def each
    @entries.transpose.each do |row|
      row.each do |sq|
        yield sq
      end
    end
  end
  
  def to_s
    "<Grid:#{object_id}>"
  end
  
  def inspect; to_s; end
  
end

Square = Struct.new(:x,:y,:grid,:room,:doors) do
  def initialize(*args)
    super
    self.doors ||= []
  end
  def north; grid[x,y-1]; end
  def south; grid[x,y+1]; end
  def east;  grid[x+1,y]; end
  def west;  grid[x-1,y]; end
  def neighbors
    [north,south,east,west].compact
  end
  def to_s
    "<Square:#{x},#{y}>"
  end
  def inspect; to_s; end
  def add_door_to(other_room)
    raise(ArgumentError,"Shouldn't put a door from a room to itself!") if other_room == self.room
    destination_square = neighbors.pick {|s| s.room == other_room }
    raise(ArgumentError,"#{self} does not border #{other_room}!") unless destination_square
    self.doors << destination_square
    destination_square.doors << self
  end
  
end

class Room
  attr_accessor :squares,:door_to,:adjacent_to,:graph
  def initialize(squares = [],door_to = [],adjacent_to = [],graph = nil)
    @squares, @door_to, @adjacent_to, @graph = squares, door_to, adjacent_to, graph
    squares.each {|s| s.room = self}
  end
  def include?(s)
    squares.include?(s)
  end
  def size
    squares.size
  end
  def to_s
    "<Room:#{object_id}>"
  end
  def inspect
    "<Room:#{object_id} @squares=#{squares}; @door_to=#{door_to}; @adjacent_to=#{adjacent_to.map {|a| a.to_s}}; @graph=#{graph}>"
  end
  def merge(other)
    raise("#{self},#{other}") if $merged_rooms.include?(self) || $merged_rooms.include?(other)
    $merged_rooms << self
    $merged_rooms << other
    all_squares = self.squares + other.squares
    all_door_to = (self.door_to + other.door_to).uniq
    all_adjacent_to = (self.adjacent_to + other.adjacent_to - [self] - [other]).uniq
    result = Room.new(all_squares,all_door_to,all_adjacent_to)
    all_adjacent_to.each {|r| r.adjacent_to.delete(self); r.adjacent_to.delete(other); r.adjacent_to << result}
    all_door_to.each {|r| r.door_to.delete(self); r.door_to.delete(other); r.door_to << result}
    all_graph = self.graph.merge(other.graph)
    all_graph.rooms.delete(self); all_graph.rooms.delete(other); all_graph.rooms<<(result); result.graph = all_graph
    puts "Merging #{self} with #{other} to produce #{result}."
    return result
  end
  
  def add_door_to(other)
    puts "Connecting #{self} with #{other} with a door."
    square = squares.pick {|sq| sq.neighbors.any? {|n| n.room == other}}
    raise(ArgumentError,"Rooms not adjacent!") unless square
    self.adjacent_to.delete(other)
    other.adjacent_to.delete(self)
    self.door_to << other
    other.door_to << self
    square.add_door_to(other)
    self.graph.merge(other.graph)
    return self
  end
  
end
class Graph 
  attr_accessor :rooms, :adjacent_to
  def initialize(rooms=[],adjacent_to=[])
    @rooms, @adjacent_to = rooms, adjacent_to
    rooms.each {|r| r.graph = self}
  end
  def squares
    rooms.map {|r| r.squares}.flatten
  end
  def merge(other)
    raise("#{self},#{other}") if $merged_graphs.include?(self) || $merged_graphs.include?(other)
    $merged_graphs << self; $merged_graphs << other
    all_rooms = self.rooms + other.rooms
    all_adjacent_to = self.adjacent_to + other.adjacent_to
    all_adjacent_to.delete(self)
    all_adjacent_to.delete(other)
    all_adjacent_to.uniq!
    result = Graph.new(all_rooms,all_adjacent_to)
    all_adjacent_to.each {|g| g.adjacent_to.delete(self); g.adjacent_to.delete(other); g.adjacent_to << result}
    puts "Merging #{self} with #{other} to produce #{result}."
    return result
  end
  def to_s
    "<Graph:#{object_id}>"
  end
  def inspect; to_s; end
  
end


WIDTH     = 20
HEIGHT    = 20
NUM_ROOMS = 10
MAX_ROOM_SIZE = 6
FIRST_STOP_SIZE = 5

class DungeonMaker
  attr_reader :squares, :rooms
  def construct_dungeon
    @squares = Grid.new(WIDTH,HEIGHT)
    @rooms = []
    @all_graphs = []
    def @all_graphs.<<(graph)
      raise unless graph
      super
    end

    create_squares

  
    fill_adjacency
    until @all_graphs.size == 1
      puts "Graphs: #{@all_graphs.size}"
      puts "Rooms: #{@rooms.size}"
      merge_or_link_rooms
    end
    
    check_everything
  end

  def check_everything
    @all_graphs.each do |g|
      g.rooms.each do |r|
        raise("Room-graph mismatch!") unless r.graph == g
        r.squares.each do |s|
          raise("Square-room mismatch!") unless s.room == r
        end
        r.door_to.each do |d|
          raise("Door mismatch!") unless d.door_to.include?(r)
        end
        r.adjacent_to.each do |a|
          raise("Adjacency mismatch!") unless a.adjacent_to.include?(r)
        end
      end
    end
  end

  def create_squares
    WIDTH.times do |x|
      HEIGHT.times do |y|
        s = Square.new(x,y,@squares)
        r = Room.new([s])
        g = Graph.new([r])
        @squares << s
        @rooms << r
        @all_graphs << g
      end
    end
  end

  def fill_adjacency
    @squares.each do |sq|
      sq.room.adjacent_to = sq.neighbors.map {|s| s.room }
      sq.room.graph.adjacent_to = sq.neighbors.map {|s| s.room.graph } 
    end
  end

  def merge_or_link_rooms
    first_graph =  @all_graphs.pick
    second_graph = first_graph.adjacent_to.pick
  
    connect_graphs(first_graph,second_graph)
  
  end

  def connect_graphs(graph_a,graph_b)
    puts "Picked #{graph_a} and #{graph_b}."
    room_a = graph_a.rooms.pick {|room| room.adjacent_to.any? {|r| r.graph == graph_b } }
    room_b = room_a.adjacent_to.pick {|r| r.graph == graph_b}
  
    link_rooms(room_a,room_b)
  end

  def link_rooms(room_a,room_b)
    @all_graphs.delete(room_a.graph)
    @all_graphs.delete(room_b.graph)
    if room_a.size > FIRST_STOP_SIZE || room_b.size > FIRST_STOP_SIZE || room_a.size + room_b.size > MAX_ROOM_SIZE
      room_a.add_door_to(room_b)
      @all_graphs << room_a.graph
    else
      @rooms.delete(room_a)
      @rooms.delete(room_b)
      result = room_a.merge(room_b)
      @rooms << result
      @all_graphs << result.graph
    end
  end
  
  def pick_rooms(num_rooms)
    picked_rooms = [@rooms.pick]
    weighted_list = picked_rooms.dup
    until picked_rooms.size == num_rooms
      selected = weighted_list.pick {|r| !(r.door_to - picked_rooms).empty? }
      picked = (selected.door_to - picked_rooms).pick
      picked_rooms << picked
      weighted_list.concat [picked]*picked_rooms.size
    end
    return picked_rooms
    
  end
  
end

require 'gosu'
class Window < Gosu::Window
  def initialize
    super(WIDTH*20,HEIGHT*20,false)
    setup
  end
  
  def setup
    @d = DungeonMaker.new
    @d.construct_dungeon
    @picked_rooms = @d.pick_rooms(rand(10)+5)
    puts @picked_rooms.size
    puts @picked_rooms.uniq.size
    @room_index = 0
    @north = true; @south = true; @east = true; @west = true
    @needs_redraw = true
  end
  
  def current_room
    @d.rooms[@room_index]
  end
  
  def needs_redraw?
    @needs_redraw
  end
  
  def button_down(id)
    redraw = true
    case id
    when Gosu::KbSpace
      @room_index += 1
      @room_index %= @d.rooms.size 
    when Gosu::KbR
      setup
    when Gosu::KbEscape
      close
    else
      redraw = false
    end
    @needs_redraw ||= redraw
  end
  
  
  def draw
    @d.squares.each do |sq|
      draw_square(sq)
    end
    draw_room(current_room)
    @needs_redraw = false
  end
  
  def draw_room(room)
    room.squares.each do |sq|
      upper_y = sq.y * 20 + 1
      left_x  = sq.x * 20 + 1
      lower_y = (sq.y+1) * 20 - 1
      right_x = (sq.x+1) * 20 - 1 
      c = 0xFF0000FF
      draw_quad(left_x,upper_y,c,right_x,upper_y,c,left_x,lower_y,c,right_x,lower_y,c)
    end
  end
  
  def draw_square(sq)
    [:north,:south,:east,:west].each do |dir|
      draw_edge(sq,dir)
    end
  end
  
  def draw_edge(sq,dir)
    other = sq.send(dir)
    if other.nil?
      draw_wall(sq,dir)
    elsif sq.room == other.room
      # draw nothing
    elsif sq.doors.include?(other)
      draw_door(sq,dir)
    else
      draw_wall(sq,dir)
    end
  end
    
  def draw_door(sq,dir)
    draw_edge_color(sq,dir,0xFF00FF00)
  end
  
  def draw_wall(sq,dir)
    draw_edge_color(sq,dir,0xFFFFFFFF)
  end
  
  def draw_edge_color(sq,dir,color)
    upper_y = sq.y * 20
    left_x  = sq.x * 20
    lower_y = (sq.y+1) * 20
    right_x = (sq.x+1) * 20
    upper_left = [left_x,upper_y]
    lower_left = [left_x,lower_y]
    upper_right = [right_x,upper_y]
    lower_right = [right_x,lower_y]
    a,b = case dir
    when :north then [upper_right,upper_left] 
    when :south then [lower_right,lower_left]
    when :east then [upper_right,lower_right]
    when :west then [upper_left,lower_left]
    else raise
    end
    color = @picked_rooms.include?(sq.room) ? color : color - 0xAA000000
    z = @picked_rooms.include?(sq) ? 2 : 1
    draw_a_line(a,b,color,z)
  end
  
  def draw_a_line(a,b,c,z)
    x1,y1 = a
    x2,y2 = b
    draw_line(x1,y1,c,x2,y2,c,z)
  end
  
end

Window.new.show

=begin

Dungeon: belongs_to party
         has_many rooms
         has_many occupants (through rooms)
         has_many terrain features (through rooms)
         has loads of convenience methods for retrieving information about its parts.
Room: has_many blocks (or has a string/serialized data structure describing the blocks)
      has_many doors (door has two rooms and x,y coordinates)
      has_many adjacent rooms (through doors)
      has_a layout (or floor plan or style or some such)
      has_many occupants (or possibly, occupations, being its own model with a room, an occupant, an x and a y coordinate)
      has_many terrain_features (possibly through layout)


=end