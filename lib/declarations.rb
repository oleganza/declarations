require 'absolutely_all_ancestors'
# We want to have module methods like has_many, validates_presence_of, after_save etc.
# Scenarios:
#   Given a module A with such declarations, 
#     we include A into B,
#     B has declaration methods and inherits the data from C.
#   Given a class C with such declarations,
#     we inherit D from C,
#     D has declaration methods and inherits the data from C.
#   Given a module A mixed in B, C
#     we add declarations
#     B and C get these declarations and inherit data from A.
#   Given a class C with subclasses D1, D2
#     we add declarations
#     D1, D2 get these declarations and inherit data from C.
#   Given a module A mixed in B, C
#     we modify declarations
#     B and C inherit data from A.
#   Given a class C with subclasses D1, D2
#     we modify declarations
#     D1, D2 inherit data from C.
#
# Issue: when we have an hierarchy of plain modules and extend some of them with a DSL,
# all children must be extended with this DSL, right?
# Design options:
# 1. keep lists of backreferences to children, this gonna waste the memory.
# 2. handle Module#method_missing in such way, that it searches ancestors for the desired method
#    and extends the module with the missing declarations.
# 3. don't try to be THAT smart and simply tell user to "extend MyDSL" the module in case of such issue.
#
# We choose to be smartass (option 2). See ModuleMethods below.
#
module Declarations
  
  def include(mod)
    invalidate_decl_cache!
    mod.extend(Declarations)
    mod.send(:register_cache,self) # self must be invalidated when mod's ancestors are modified
    super
  end
  
  NOTHING = Object.new.freeze # unique object representing undefined value.

  def local_declarations(name, default = NOTHING, &blk)
    decls = (@local_declarations ||= Hash.new(NOTHING))
    decls[name] = default if decls[name].equal?(NOTHING)
    return local_declarations_set(name, yield(decls[name])) if block_given?
    decls[name]
  end

  def local_declarations_set(name, value)
    decls = (@local_declarations ||= {})
    decls[name] = value
    invalidate_decl_cache!
    value
  end
  
  def local_declarations_remove(name)
    decls = (@local_declarations ||= {})
    decls.delete(name)
    invalidate_decl_cache!
    nil
  end

  def inherited_declarations(name)
    decls = @inherited_declarations
    decls and data = decls[name] and return data
    @inherited_declarations ||= {}
    inherited_data = absolutely_all_ancestors.inject([]) do |memo, ancestor|
      ancestor.extend(Declarations)
      ancestor.send(:register_cache, self)
      local_decls = ancestor.local_declarations(name)
      memo << local_decls unless local_decls.equal?(NOTHING)
      memo
    end
    @inherited_declarations[name] = if block_given?
      yield(inherited_data)
    else
      inherited_data
    end
  end

private

  def register_cache(mod)
    @decl_cached_objects ||= []
    @decl_cached_objects |= [mod]
  end
  
  # It is rude to invalidate all possible DSLs when only one 
  # DSL inheritance chain is modified, but it is very effective.
  def invalidate_decl_cache!
    return unless @decl_cached_objects
    @decl_cached_objects.each do |mod|
      mod.instance_variable_set(:@inherited_declarations, nil)
    end
  end
  
  module ModuleMethods
    # Search ancestors for the missing method
    def method_missing(meth, *args, &blk)
      # 0. If this is a DSL and Declarations were included lazily,
      #    module may not have these methods. Extend it with them
      if Declarations.instance_methods.include?(meth.to_s) and !is_a?(Declarations)
        extend(Declarations)
        return send(meth, *args, &blk)
      end
      
      # 1. Find nearest module with all 
      # FIXME: remove this step as redundant?
      mod_with_dsl = absolutely_all_ancestors.detect {|a| a.respond_to?(meth) }
      super(meth, *args, &blk) unless mod_with_dsl

      # 2. extended self with all the DSLs found in this module
      all_were_extended = true
      amc = (class<<mod_with_dsl;self;end)
      amc.absolutely_all_ancestors.each do |dsl|
        unless dsl.is_a?(Class)
          unless self.is_a?(dsl)
            all_were_extended = false
            extend(dsl)
          end
        end
      end
      # 3. try again if no circular dependency detected
      unless all_were_extended
        return send(meth, *args, &blk) 
      end
      super(meth, *args, &blk)
    end
  end # ModuleMethods
end # Declarations

class Module  
  include Declarations::ModuleMethods
end
