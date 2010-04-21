require 'enumerator' unless defined? Enumerator

module Pickable
  def pick(count = nil, &blk)
    set = block_given? ? self.enum_for(:each).select(&blk) : self
    if count.nil?
      return set[rand(set.length)]
    else
      return set.sort_by {rand}.first(count)
    end
  end
end

module Enumerable
  include Pickable
end

# Array already includes enumerable, but, due to the Double-inclusion problem,
# (also called the "Dynamic Module Inclusion Problem"), we have to include it
# again for array to pick up the new features we added by including Pickable.
module Array
  include Enumerable
end