#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint ar_location_view.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'ar_location_view'
  s.version          = '3.1.0'
  s.summary          = 'Location-based augmented reality for Flutter.'
  s.description      = <<-DESC
Streams the device heading and attitude used by the ar_location_view Flutter
plugin to place geolocated points of interest over the camera preview.
                       DESC
  s.homepage         = 'https://github.com/Melo567/ar_location_view'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Melo567' => 'https://github.com/Melo567' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.resource_bundles = { 'ar_location_view_privacy' => ['Resources/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
