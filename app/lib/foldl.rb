# Taken from epitron/epitools/Enumerable
module Enumerable
  def foldl(methodname=nil, &block)
    result = nil

    raise "Error: pass a parameter OR a block, not both!" unless !!methodname ^ block_given?

    if methodname
      each_with_index do |e,i|
        if i == 0
          result = e
          next
        end
        result = result.send(methodname, e)
      end
    else
      each_with_index do |e,i|
        if i == 0
          result = e
          next
        end
        result = block.call(result, e)
      end
    end
    result
  end
end
