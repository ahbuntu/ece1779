class AutoScale
  include Singleton
  
  class << self

    def set_options (grow_cpu_val, shrink_cpu_val, grow_ratio_val, shrink_ratio_val)
      @grow_cpu = grow_cpu_val
      @shrink_cpu = shrink_cpu_val
      @grow_ratio = grow_ratio_val
      @shrink_ratio = shrink_ratio_val
    end
    
    def grow_cpu
      @grow_cpu
    end

    def shrink_cpu
      @shrink_cpu
    end

    def grow_ratio
      @grow_ratio
    end

    def shrink_ratio
      @shrink_ratio
    end
  end

end
