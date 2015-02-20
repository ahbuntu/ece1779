class AutoScale
  include Singleton
  
  class << self

    def set_options (grow_cpu_val, shrink_cpu_val, grow_ratio_val, shrink_ratio_val)
      @grow_cpu = grow_cpu_val
      @shrink_cpu = shrink_cpu_val
      @grow_ratio = grow_ratio_val
      @shrink_ratio = shrink_ratio_val
    end
    

    def set_values (grow_cpu_threshVal, shrink_cpu_threshVal, grow_ratio_threshVal, shrink_ratio_threshVal)
      @grow_cpu_thresh = grow_cpu_threshVal
      @shrink_cpu_thresh = shrink_cpu_threshVal
      @grow_ratio_thresh = grow_ratio_threshVal
      @shrink_ratio_thresh = shrink_ratio_threshVal
    end
    

    def is_grow_cpu
      @grow_cpu
    end

    def is_shrink_cpu
      @shrink_cpu
    end

    def is_grow_ratio
      @grow_ratio
    end

    def is_shrink_ratio
      @shrink_ratio
    end

    def grow_cpu_thresh
      @grow_cpu_thresh
    end

    def shrink_cpu_thresh
      @shrink_cpu_thresh
    end

    def grow_ratio_thresh
      @grow_ratio_thresh
    end

    def shrink_ratio_thresh
      @shrink_ratio_thresh
    end
  end

end
