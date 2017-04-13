Pod::Spec.new do |s|
  s.name         = "JLRoutes"
  s.version      = "2.0.5"
  s.summary      = "URL routing library for iOS with a simple block-based API."
  s.homepage     = "https://github.com/joeldev/JLRoutes"
  s.license      = "BSD 3-Clause \"New\" License"
  s.author       = { "Joel Levin" => "joel@joeldev.com" }
  s.source       = { :git => "https://github.com/joeldev/JLRoutes.git", :tag => "2.0.5" }
  s.framework    = 'Foundation'
  s.requires_arc = true

  s.source_files = 'JLRoutes', 'JLRoutes/*.{h,m}', 'JLRoutes/Classes/*.{h,m}'

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
end
