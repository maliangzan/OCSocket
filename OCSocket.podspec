Pod::Spec.new do |spec|
  spec.name         = 'OCSocket'
  spec.version      = '1.0.0'
  spec.summary      = 'OCSocket'
  spec.license      =  'MIT'
  spec.authors      = {'maliangzan' => 'maliangzan@126.com'}
  spec.author       `= { "mako" => "maliangzan@126.com" }
  spec.platform     = :ios, '9.0'
  spec.ios.deployment_target = '9.0'
  spec.source_files = 'OCSocket/**.{h,m}'
  spec.requires_arc = true
  spec.homepage = 'https://github.com/maliangzan/OCSocket'
  spec.source = {:git => 'https://github.com/maliangzan/OCSocket.git', :tag => spec.version}
  spec.description = <<-DESC
                                智能家居OCSocket
                       DESC




end
