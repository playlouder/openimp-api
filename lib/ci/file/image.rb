class CI::File::Image < CI::File
  ci_properties :Width, :Height
  
  RESIZE_METHODS = [
    'NOMODIFIER',
    'EXACT',
    'SQUARE',
    'SMALLER',
    'LARGER'
  ]
  
  RESIZE_TYPES = {
    'jpeg' => 'jpg',
    'png' => 'png',
    'tiff' => 'tiff',
    'gif' => 'gif'
  }
  
  def initialize(params={}, data=nil, mime_type=nil)
    super(params, data, mime_type)
    cast_as(self.class) unless __class__ == 'API::File::Image' #Looks tautological, but we need to let the server know that this is an Image.
  end
  

  def resize(target_width=nil, target_height=nil, method=nil, target_type=nil, token_properties=nil, synchronous=true)
    self.store
    method ||= 'NOMODIFIER'
    target_width ||= width
    target_height ||= height
    target_type ||= RESIZE_TYPES[mime_minor]
    target_type = target_type.to_s #if a symbol was passed.
    raise "target image type not recognised" unless RESIZE_TYPES.values.include?(target_type)
    raise  "resize method not recognised" unless RESIZE_METHODS.include?(method)
    method = "IMAGE_RESIZE_#{method}"
    params = {:targetY => target_height, :targetX =>target_width, :targetType => target_type, :resizeType => method}
    params.merge!(:Synchronous => 'on') if synchronous
    if token_properties
      params.merge!(token_properties)
      CI::FileToken.do_request(:post, "/#{id}/contextualmethod/Resize/createfiletoken", nil, nil, params)
    else
      CI::File::Image.do_request(:post, "/#{id}/contextualmethod/Resize", nil, nil, params)
    end
  end
end