class Manager::WorkersController < ManagerController
  def index
    @workers = []

    @workers << Worker.new("foo")
  end

end
