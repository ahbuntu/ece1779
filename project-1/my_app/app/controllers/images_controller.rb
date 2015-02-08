class ImagesController < ApplicationController
  ImagesController::BUCKET = "ece1779"

  # Assumption: the load-testing utility doesn't login or maintain a session
  skip_before_action :authenticate, only: :create

  before_action :set_image, only: [:show, :edit, :update, :destroy]
  protect_from_forgery :except => :create 

  def index
    @images = current_user.images
  end

  def new
    @image = Image.new
  end

  def create
    # We get two kinds of POSTs here:
    # 1) regular users (who have logged in) and are POSTing with the standard form on the browser
    # 2) the load-testing utility (assumption: which doesn't login)
    #
    # For #1, we follow the regular Rails conventions (params[:image] contains the POST data)
    # For #2, we assume that the POST data is at the top level of params
    #
    # Test #2 with:
    #   curl --form "theFile=@my-file.txt;filename=desired-filename.txt" --form userID=1 --form param2=value2 http://127.0.0.1:3000/ece1779/servlet/FileUpload
    #
    # In both cases, we expect params[:userID] to be present.
    @current_user = User.find params[:userID]

    safe_params = params[:image].present? ? image_params(params[:image]) : image_params(params)

    @image = Image.new(safe_params)
    respond_to do |format|
      if @image.save # this dispatches UploadImageOriginalWorker
        format.html { redirect_to user_image_path(@current_user, @image), notice: 'Image was successfully uploaded.' }
        format.json { render :show, status: :created, location: @image }
      else
        @image.file = nil # cleanup
        format.html { render :new }
        format.json { render json: @image.errors, status: :unprocessable_entity }
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    # no current_user found
    respond_to do |format|
      format.html { redirect_to root_path, notice: 'You do not have an account.', status: :unauthorized }
      format.json { head :unauthorized }
    end
  end

  def update
    respond_to do |format|
      if @image.update(image_params)
        format.html { redirect_to @image, notice: 'Image was successfully updated.' }
        format.json { render :show, status: :ok, location: @image }
      else
        format.html { render :edit }
        format.json { render json: @image.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @image.destroy
    respond_to do |format|
      format.html { redirect_to user_images_path(current_user), notice: 'Image was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_image
    @image = Image.find params[:id]
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  # Note that the load-tester posts to non-nested params
  def image_params(params)
    # From the requirements:
    #
    # field1 name = userID type = string
    # field2 name = theFile type = file

    file = params[:theFile]
    original_filename = file.original_filename
    extension = File.extname(original_filename)

    {user: @current_user, file: file, original_filename: original_filename, extension: extension}
  end

end
