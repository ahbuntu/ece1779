class ImagesController < ApplicationController
  
  before_action :set_image, only: [:show, :edit, :update, :destroy]
  before_action :set_user, only: [:new, :create]
  protect_from_forgery :except => :create 

  def index
    @images = Image.all
  end

  def new
    @image = Image.new
  end

  # Test this with something like: 
  #   curl --form "theFile=@my-file.txt;filename=desired-filename.txt" --form userID=1 --form param2=value2 http://127.0.0.1:3000/ece1779/servlet/FileUpload
  def create
    @image = Image.new(image_params)
    respond_to do |format|
      if @image.save # this dispatches UploadImageOriginalWorker
        format.html { redirect_to new_user_image_path(@user), notice: 'Image was successfully uploaded.' }
        format.json { render :show, status: :created, location: @image }
      else
        @image.file = nil # cleanup
        format.html { render :new }
        format.json { render json: @image.errors, status: :unprocessable_entity }
      end
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
      format.html { redirect_to images_url, notice: 'Image was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_image
    @image = Image.find params[:id]
  end

  def set_user
    @user = User.find_by params[:user_id]
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def image_params
    # From the requirements:
    #
    # field1 name = userID type = string
    # field2 name = theFile type = file

    user_id = params[:userID]
    file = params[:theFile]
    original_filename = file.original_filename
    extension = File.extname(original_filename)

    user = User.find user_id
    {user: user, file: file, original_filename: original_filename, extension: extension}
  end

end
