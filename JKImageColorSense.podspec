Pod::Spec.new do |s|
  s.name         = "JKImageColorSense"
  s.summary      = "The fastest image color retrieve framework."
  s.version      = "1.0.0"
    
  s.homepage     = "https://github.com/fsjack/JKImageColorSense"
  s.license      = 'MIT'
  s.author       = { "Jackie" => "fsjack@gmil.com" }

  s.source       = { :git => "git@github.com:fsjack/JKImageColorSense.git"}
  s.source_files = 'JKImageColorArt'

  s.requires_arc = true
end
