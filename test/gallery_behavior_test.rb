require 'test/unit'
require File.dirname(__FILE__) + '/../../../../test/test_helper'
require 'RMagick'

class GalleryBehavior
  def gallery_base_path
    File.dirname(__FILE__) + "/gallery/"
  end
end

class GalleryBehaviorTest < Test::Unit::TestCase
  test_helper :behavior_render
 
  IMAGE_FILES = ['pic1.jpg', 'pic2', 'pic5.JPEG', 'pic3.PNG', 'pic6', 'pic4.tiff']
  # Replace this with your real tests.
  def setup
    # create a page_part containing a part storing the gallery
    new_page = Page.new(:title => 'Test Gallery', :slug => 'gallery-test', :breadcrumb => 'gallery', :behavior_id => 'Gallery')
    new_page.save
    @page_part_gallery= PagePart.new(:name => 'gallery', 
      :content => 'test-gallery',
      :page_id => new_page.id)
    @page_part_gallery.save
    @page_part_body = PagePart.new(:name => 'body', 
      :content => '<r:gallery/>',
      :page_id => new_page.id)
    @page_part_body.save
    @page = Page.find_by_id(new_page.id)
  end

  def test_gallery_folders
    assert_equal ['sub-gallery'],
                 @page.behavior.folders
  end
  
  def test_gallery_images
    images = []
    # this is the order I we want the images in
    counter = Time.now - IMAGE_FILES.length.seconds
    IMAGE_FILES.each { |img|
      # set a proper modification time on the images
      File.utime(counter, counter, File.join(@page.behavior.gallery_base_path, 'test-gallery', img))
      # create the image objects
      i = Magick::Image.ping(
        File.join(@page.behavior.gallery_base_path, 'test-gallery', img))
      images << i[0].filename if !i.empty?
      counter += 1.second
    }
    # compare to what the behaviour produces
    assert_equal images, @page.behavior.images.collect { |i| i.filename }
  end
 
  def test_gallery_folders_tag
    assert_renders %{<a href="/gallery-test/sub-gallery/">sub-gallery</a>}, 
                   '<r:gallery lightbox="false"><r:folders:each><r:link/></r:folders:each></r:gallery>'
  end
    
  def test_gallery_images_tag
    links = IMAGE_FILES.collect {|img|
      # chop off the extension of the images
      x = img.sub(%r{\..+$}, '')
      %{<a class="lightbox" href="/gallery-test/#{x}/medium" rel="lightbox[gallery-test]" title="#{x}">}\
      + %{<img src="/gallery-test/#{x}/thumbnail" alt="#{x}" /></a>}
    }
    assert_renders links.join(''), 
                   '<r:gallery lightbox="false"><r:images:each><r:thumbnail/></r:images:each></r:gallery>'
  end

  def test_gallery_find_page_by_url
    page = @page.behavior.find_page_by_url('/gallery-test/pic6/original')
    expected = Magick::Image.read(
      File.join(@page.behavior.gallery_base_path, 'test-gallery/pic6')
    ).last
    assert expected.to_blob == page.render, 
           'Returned image does not equal expected image.'
  end

  def test_gallery_prepare_image
    expected = Magick::Image.read(
      File.join(@page.behavior.gallery_base_path, 'test-gallery/pic5.JPEG')
    ).last
    expected.format = "PNG"
    expected = expected.change_geometry("200x200") {|cols,rows,img|
      img.resize(cols, rows)
    }
    page = @page.behavior.find_page_by_url('/gallery-test/pic5/small')
    assert expected.to_blob == page.render, 'Scaled images do not equal.'
  end

  def test_gallery_javascript
    filename = 'lightbox.js'
    path = File.join(File.dirname(__FILE__), '../lightbox/js', filename)
    expected = File.read(path)
    page = @page.behavior.find_page_by_url('/gallery-test/lightbox/js/lightbox.js')
    assert expected == page.render, 'Wrong JavaScript returned.'
  end

  def test_gallery_stylesheet
    filename = 'lightbox.css'
    path = File.join(File.dirname(__FILE__), '../lightbox/css', filename)
    expected = File.read(path)
    page = @page.behavior.find_page_by_url('/gallery-test/lightbox/css/lightbox.css')
    assert expected == page.render, 'Wrong CSS returned.'
  end

  def teardown
    @page.destroy
    @page_part_body.destroy
    @page_part_gallery.destroy
  end
end
