class AutoScale
  include Singleton
  
  class << self

    def set_state (state)
      @auto_scale = state
    end
    
    def is_enabled?
      @auto_scale
    end

    def set_values (grow_cpu_threshVal, shrink_cpu_threshVal, grow_ratio_threshVal, shrink_ratio_threshVal)
      @grow_cpu_thresh = grow_cpu_threshVal
      @shrink_cpu_thresh = shrink_cpu_threshVal
      @grow_ratio_thresh = grow_ratio_threshVal
      @shrink_ratio_thresh = shrink_ratio_threshVal
    end
    

    def is_grow_cpu
      grow_cpu_thresh.present?
    end

    def is_shrink_cpu
      @shrink_cpu_thresh.present?
    end

    def is_grow_ratio
      @grow_ratio_thresh.present?
    end

    def is_shrink_ratio
      @shrink_ratio_thresh.present?
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
