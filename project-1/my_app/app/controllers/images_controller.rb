class ImagesController < ApplicationController
  ImagesController::BUCKET = "ece1779"

  before_action :set_image, only: [:show, :edit, :update, :destroy]
  before_action :correct_user, only: [:new]
  protect_from_forgery :except => :create 

  def index
    @images = Image.all
  end

  def new
    @image = Image.new
    if !current_user.present?
      set_user_noauth
    end
  end

  # Test this with something like: 
  #   "curl --form "theFile=@my-file.txt;filename=desired-filename.txt" --form userID=1 --form param2=value2 http://127.0.0.1:3000/ece1779/servlet/FileUpload"
  def create
    @image = Image.new(image_params)
    @image.save

    if !current_user.present?
      set_user_noauth
    end

    uploadedFile = params[:image][:theFile]
    #follow virtual directory structure /images/<user_id>/<image_id>/<transformation>
    awsFilePath = File.join('images',params[:userID], @image.id.to_s)
    awskey1 = File.join(awsFilePath, 'original')

    s3 = AWS::S3.new
    #TODO: rename the base bucket
    bucket = s3.buckets[ImagesController::BUCKET]    
    object = bucket.objects[awskey1] 
    object.write(:file => uploadedFile.path)
    #update S3 key1 for the image
    @image.key1 = awskey1
    #TODO: need to store the original filename into database

    #open creates a copy of the image
    image = MiniMagick::Image.open(uploadedFile.path)
    #image.path #prints the path of the copied image
    image.resize "100x100"
    image.format "png"
    image.write "public/output.png"

    respond_to do |format|
      if @image.save
        format.html { redirect_to new_user_image_path(@current_user), notice: 'Image was successfully uploaded.' }
        format.json { render :show, status: :created, location: @image }
      else
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

  def set_user_noauth
    @current_user = User.find_by params[:userID]
  end

  def correct_user
    user = User.find(params[:user_id])
    if !current_user?(user)
      # Redirect to log in with error message
      redirect_to(root_url, alert: 'You are not authorized. Please log in.') 
    end
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def image_params
    # From the requirements:
    #
    # field1 name = userID type = string
    # field2 name = theFile type = file

    user_id = params[:userID]
    file = params[:theFile]

    user = User.find user_id
    {user: user}
  end

end
