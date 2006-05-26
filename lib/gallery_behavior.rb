require 'RMagick'

class GalleryBehavior < Behavior::Base
  
  register "Gallery"
 
  LOGGER = ActionController::Base.logger
  
  VARIANTS = { 'thumbnail' => [100, 100],
               'small' => [200, 200],
               'medium' => [400, 400],
               'large' => [600, 600],
               'xlarge' => [800, 800],
               'original' => nil }
               
  description %{
    The Gallery behaviour allows a page to act as an image gallery. The raw
    image is stored on the file system and the behaviour provides access to
    the image through RMagick. The actual gallery is realized using
    Lightbox v2 and the behaviour only generates the appropriate Lightbox
    links for the images found on the file system. Additionally RMagick
    also takes care of scaling the image to a desirable size for
    thumbnails and larger sizes.

    The only requirements for this behaviour are a working Radiant
    installation and RMagick installation. To get RMagick you can install
    the Ruby gem using:

      gem install rmagick

    The behaviour also does not require any specific installation steps.
    Just unpack the plugin in the 'vendor/plugins' directory of your
    Radiant installation and restart the webserver. Any additional files
    such as the Lightbox Javascripts or CSS are provided through the
    Gallery behaviour and do not need to be explicitly installed.
    
    A gallery pages consists of two required parts: 'gallery' and 'body'.
    The 'gallery' part is used to configure the gallery and contains the
    filesystem directory on the server from which the gallery should be
    created. The path specified here is a path relative to
    '$RAILS_ROOT/public'. For example if the gallery should be bound to
    '$RAILS_ROOT/public/photos/Canada/' the 'gallery' part should contain a
    single line 'photos/Canada'.

    The 'body' part is used for structuring the output of the Gallery
    behaviour. To do so, the behaviour provides the following tags:
    
      <r:gallery [lightbox="false"]>
         
        Sets up the gallery environment. The optional attribute
        'lightbox="false"' causes the tag to NOT generate any Lightbox
        specific '<script>' or '<link>' tags. Note, that when the Lightbox
        tags are generated HTML conformance will be broken, since '<link>'
        tags are not allowed in the HTML body, though most browsers still
        interprete the tag.

      <r:gallery:if_subgallery>

        Renders the content of this tag only if the currently displayed
        gallery is a subfolder of the folder bound using the 'gallery' page
        part. For the example above: assume the page '/traveling' is a
        gallery bound to 'photos/Canada' and 'photos/Canada' contains a
        subfolder 'Nova_Scotia', then if the currently displayed page is
        '/traveling/Nova_Scotia', the current page is a subgallery of
        '/traveling/' and the content of the '<r:if_subgallery>' tag is
        rendered. This tag can be used to generate navigational links, e.g.
        to parent galleries. See <r:gallery:parent:url>

      <r:gallery:parent:url/>

        Returns the URL of the parent gallery if such gallery exists.
        Usage example: 
          <a href="<r:gallery:parent:url/>">Go one level up</a>

      <r:gallery:folders:each>

        Iterates over each subfolder in the currently displayed gallery.
        
      <r:gallery:folders:each:link>

        Generates a link to the current subfolder.

      <r:gallery:images:each>

        Iterates over each image in the currently displayed gallery.

      <r:gallery:images:each:thumbnail>

        Generates a thumbnail link to a large version of the image. The
        link generated is compatible with Lightbox such that Lightbox can
        be used to 'click' through the larger images. If Lightbox is not
        present, the link will act like a normal link.

    Example:

    A typical example for a gallery page is the following: assume again
    the images you want to display are organized in a directory structure
    underneath $RAILS_ROOT/public/images/Canada. You now want to create a
    page in your Radiant CMS '/traveling' which is bound to that
    directory. To do so, you create a child for the 'root' page and give it
    the title 'Traveling' (this causes the slug to be 'traveling'). Now you
    remove the 'extended' page part and create a new page part called
    'gallery'. In the gallery page part you now enter the path relative to
    $RAILS_ROOT/public which you want to have bound to the gallery. In this
    example this is 'images/Canada'. Now you can fill the 'body' page part
    with HTML code and tags of your choice, e.g.:
    
    <r:gallery>

     <!-- check if parent gallery exists -->
     <r:if_subgallery>
      <a href="<r:parent:url/>">go up</a>
     </r:if_subgallery> 
     <div>
      Subfolders:
      <!-- list all subfolders -->
      <ul class="subgalleries">
       <r:folders:each>
        <li><r:link/></li>
       </r:folders:each>
      </ul>
     </div>
     <div>
      <!-- generate thumbnail links for images -->
      <r:images:each>
       <span class="thumbnail">
        <div>
          <r:thumbnail/>          
        </div>
       </span>
      </r:images:each>
     </div>
    </r:gallery>

    Finally set your favourite layout and make sure you use the 'Gallery'
    page behaviour.

    Todo:

    - allow user to specify thumbnail size and view size
    - custom sizes through configuration part
    - preview thumbnail of sub gallery
    - EXIF rotation and sorting
  }
 
  # TODO allow user to specify thumbnail size and view size
  # TODO custom size through configuration part
  define_tags do
    tag 'gallery:if_subgallery' do |tag|
      if !@inner_path.empty?
        tag.expand
      else
        ''
      end
    end
     
    tag 'gallery:parent' do |tag|
      tag.expand
    end

    tag 'gallery:parent:url' do |tag|
      if !@inner_path.empty?
        page.url + @inner_path.split(/\//)[0..-2].join('/') + '/'
      else
        page.url
      end
    end

    tag 'gallery:images' do |tag|
      tag.expand
    end
    
    tag 'gallery:folders' do |tag|
      tag.expand
    end
    
    tag 'gallery:images:each' do |tag|
      content = ''
      images.each { |img|
        tag.locals.image = img
        content << tag.expand
      }
      content
    end
    
    tag 'gallery:images:each:thumbnail' do |tag|
      image_name = inner_path \
        + sub_extension(File.basename(tag.locals.image.filename))
      %{<a class="lightbox" href="#{page.url}#{image_name}/medium" } \
      + %{rel="lightbox[#{page.slug}]" title="#{image_name}">} \
      + %{<img src="#{page.url}#{image_name}/thumbnail" }\
      + %{alt="#{image_name}" /></a>}
    end

    tag 'gallery:folders:each' do |tag|
      content = ''
      folders.each { |f|
        tag.locals.folder = f
        content << tag.expand
      }
      content
    end
    
    tag 'gallery:folders:each:link' do |tag|
      f = tag.locals.folder
      %{<a href="#{page.url}#{inner_path + f}/">#{f}</a>}
    end

    tag 'gallery' do |tag|
      content = ''
      if tag.attr['lightbox'] != 'false'
        content << 
          %{<link rel="stylesheet" href="#{page.url}lightbox/css/lightbox.css" type="text/css" media="screen" />
          <script src="#{page.url}lightbox/js/prototype.js" type="text/javascript"></script>
          <script src="#{page.url}lightbox/js/scriptaculous.js?load=effects" type="text/javascript"></script>
          <script src="#{page.url}lightbox/js/lightbox.js" type="text/javascript"></script>}
      end
      content << tag.expand
      content
    end
  end
  
  def sub_extension(filename)
    filename.sub(%r{(\.jpg|\.jpeg|\.tif|\.tiff|\.png|\.gif)$}i, '')
  end
    
  def render_page
    @content
  end
  
  def folder?
    FileTest.directory?(File.join(gallery_local_path, inner_path))
  end

  def find_page_by_url(url, live = true, clean = false)
    @content = nil
    @inner_path = url.sub(@page.url, '')
    if @inner_path =~ /lightbox\/(images|css|js)\/.+$/
      process_lightbox
    elsif folder?
      @content_type = nil
      lazy_initialize_parser_and_context
      if layout = @page.layout
        @content = parse_object(layout)
      else
        @content = render_page_part(:body)
      end
    else
      @image = nil
      @inner_path.sub!(/\/$/, '')
      splits = @inner_path.split(/\//)
      if VARIANTS.has_key?(splits.last)
        @inner_path.sub!(%r{/#{splits.last}$}, '')
        filename = File.basename(inner_path)
        dirname = File.join(gallery_local_path, File.dirname(inner_path))
        Dir.open(dirname) { |gallery|
          gallery.each { |file|
            if sub_extension(file) == filename
              begin
                image = Magick::Image.read(File.join(dirname, file)).first
              rescue
              end
              @image = prepare_image(image, splits.last)
              @content_type = @image.mime_type
              break
            end
          }
        }
      end
      @content = @image.to_blob if !@image.nil?
    end
    return super if @content.nil?
    @page
  end

  JAVASCRIPTS = ['prototype.js', 'scriptaculous.js', 
                 'effects.js', 'lightbox.js']
  STYLESHEETS = ['lightbox.css']
  IMAGES = ['blank.gif', 'close.gif', 'closelabel.gif', 'loading.gif',
            'next.gif', 'nextlabel.gif', 'prev.gif', 'prevlabel.gif']
  def process_lightbox
    filename = inner_path.split(/\//).last
    if JAVASCRIPTS.include?(filename)
      @content_type = 'text/javascript'
      filename = File.join(File.dirname(__FILE__), 
                           '../lightbox/js/', filename)
      @content = File.read(filename)
    elsif STYLESHEETS.include?(filename)
      @content_type = 'text/css'
      filename = File.join(File.dirname(__FILE__), 
                           '../lightbox/css/', filename)
      @content = File.read(filename)
    elsif IMAGES.include?(filename)
      @content_type = 'image/gif'
      filename = File.join(File.dirname(__FILE__), 
                           '../lightbox/images/', filename)
      @content = File.read(filename)
    end
  end
 
  # TODO add EXIF rotation
  def prepare_image(image, variant)
    if VARIANTS[variant].nil?
      image
    else
      # only scale if the image is actually larger than the requested size
      if image.columns > VARIANTS[variant][0] \
          or image.rows > VARIANTS[variant][1] 
        image.format = "PNG"
        image = \
          image.change_geometry(VARIANTS[variant].join('x')) {|cols,rows,img|
            img.resize(cols, rows)
          }
      end
      image
    end
  end

  def cache_page?
    false
  end

  def page_headers
    headers = { 'Status' => ActionController::Base::DEFAULT_RENDER_STATUS_CODE }
    headers.update({ 'Content-type' => @content_type }) if !@content_type.nil?
    headers
  end
  
  def gallery_local_path
    File.join(gallery_base_path, gallery_path)
  end
  
  def gallery_path
    @page.part('gallery').content
  end

  def gallery_base_path
    File.join(RAILS_ROOT, 'public')
  end
  
  def inner_path
    @inner_path ||= ''
  end

  def gallery_content
    content = []
    Dir.open(File.join(gallery_local_path, inner_path)) { |gallery|
        # get the content of the directory and compute the local path name
        content = gallery.collect { |file| 
          File.join(gallery.path, file)
      }
    }
    content
  end
  
  def folders
    gallery_content.collect { |file|
      # only keep directories
      File.basename(file) if FileTest.directory?(file) \
        and File.basename(file) != '.' \
        and File.basename(file) != '..'
    }.compact
  end
  
  # TODO order by EXIF creation time
  def images
    images = []
    gallery_content.sort { |a,b|
      # sort the images by modification time
      File.mtime(a) <=> File.mtime(b)
    }.each { |file|
      # now try to create image object of the file
      begin
        image = Magick::Image.ping(file)
        images << image.first if !image.empty?
      rescue Magick::ImageMagickError
      end
    }
    images
  end
end
