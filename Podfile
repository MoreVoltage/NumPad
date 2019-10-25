# Uncomment the next line to define a global platform for your project
#plugin 'cocoapods-binary'

platform :ios, '9.3'
inhibit_all_warnings!
use_frameworks!
#enable_bitcode_for_prebuilt_frameworks!
#keep_source_code_for_prebuilt_frameworks!
#all_binary!

def shared
  pod 'Firebase/Analytics', '~> 6.11'
  pod 'Crashlytics', '~> 3.14'
  pod 'TinyConstraints', '~> 3.3' #4.0.1
end

target 'Keyboard' do
  shared
  pod 'DynamicColor', '~> 4.2'
  pod 'SwiftyTimer', '~> 2.1'
end

target 'NumPad' do
  shared
  pod 'SwiftRater', '~> 1.6'
  pod 'RevealingSplashView', '~> 0.6'
  pod 'TextAttributes', :git => 'https://github.com/annjose/TextAttributes', :branch => 'annjose-master'
end
