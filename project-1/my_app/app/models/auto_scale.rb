class AutoScale

  cattr_accessor :grow_cpu_thresh, :shrink_cpu_thresh, :grow_ratio_thresh, :shrink_ratio_thresh
  cattr_accessor :enabled, :errors

  class << self

    def valid?
      self.errors = []
      self.errors << "Growth threshold must be > shrink threshold" unless self.grow_cpu_thresh > self.shrink_cpu_thresh
      self.errors << "Growth threshold must be <= 100.0" unless self.grow_cpu_thresh <= 100.0
      self.errors << "Shrink threshold must be >= 0" unless self.shrink_cpu_thresh >= 0.0

      # "(e.g., a ratio of 2 doubles the number of workers)."
      self.errors << "Growth ratio must be >= 1.0" unless self.grow_ratio_thresh >= 1.0

      # "(e.g., a ratio of 4 shuts down 75% of the current workers)."
      self.errors << "Shrink ratio must be >= 1.0" unless self.shrink_ratio_thresh >= 1.0 
      self.errors.empty?      
    end

    def grow_cpu_thresh
      @@grow_cpu_thresh || 100.0
    end

    def shrink_cpu_thresh
      @@shrink_cpu_thresh || 0.0
    end

    def grow_ratio_thresh
      @@grow_ratio_thresh || 1.0
    end

    def shrink_ratio_thresh
      @@shrink_ratio_thresh || 1.0
    end

  end

end
