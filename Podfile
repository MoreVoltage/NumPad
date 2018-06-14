# Uncomment the next line to define a global platform for your project
platform :ios, '9.3'

def shared
    pod 'Crashlytics', '~> 3.10'
    pod 'Firebase/Core', '~> 4.13'
    pod 'TinyConstraints', '~> 3.1'
end

target 'Keyboard' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Keyboard
  shared
  pod 'DynamicColor', '~> 4.0'
  pod 'SwiftyTimer', '~> 2.0'
end

target 'NumPad' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for NumPad
  shared
  pod 'Helpshift', '7.0.1-bitcode'
  pod 'SwiftRater', '~> 1.1'
  pod 'SwiftyStoreKit', '~> 0.13'
  pod 'RevealingSplashView', '~> 0.5'
  pod 'TextAttributes', :git => 'https://github.com/ejmartin504/TextAttributes.git', :branch => 'swift4'
end
