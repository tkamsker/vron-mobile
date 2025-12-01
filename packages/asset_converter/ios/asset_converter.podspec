#
# asset_converter.podspec
#
# CocoaPods specification for asset_converter Flutter plugin
# Provides USDZ→GLB conversion and navigation mesh generation using Recast Navigation
#

Pod::Spec.new do |s|
  s.name             = 'asset_converter'
  s.version          = '1.0.0'
  s.summary          = 'Platform channel for USDZ→GLB conversion and navmesh generation'
  s.description      = <<-DESC
iOS implementation of asset_converter plugin. Provides:
- USDZ to GLB conversion using Model I/O framework
- Navigation mesh generation using Recast Navigation library
- Platform channel integration for Flutter
                       DESC
  s.homepage         = 'https://vron.one'
  s.license          = { :type => 'Proprietary', :file => '../LICENSE' }
  s.author           = { 'VRON' => 'info@vron.one' }
  s.source           = { :path => '.' }

  # Source files
  s.source_files = 'Classes/**/*.{swift,h,m,mm,cpp}'
  s.public_header_files = 'Classes/**/*.h'

  # Platform requirements
  s.platform = :ios, '14.0'
  s.ios.deployment_target = '14.0'

  # Swift configuration
  s.swift_version = '5.0'

  # Framework dependencies
  s.frameworks = 'UIKit', 'ModelIO', 'SceneKit'

  # Flutter dependency
  s.dependency 'Flutter'

  # Recast Navigation library
  # We'll include Recast Navigation as vendored source files
  # This will be added in the next step when we download/integrate Recast

  # C++ standard library (required for Recast Navigation)
  s.library = 'c++'
  s.xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }

  # Pod target xcconfig
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'SWIFT_SUPPRESS_WARNINGS' => 'YES'
  }
end
