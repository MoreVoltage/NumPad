platform :ios, '12.0'

def shared
    pod 'FirebaseAnalytics'
    pod 'FirebaseCrashlytics'
    pod 'DynamicColor'
    pod 'TinyConstraints'
end

target 'Keyboard' do
    use_frameworks! # :linkage => :static
    
    shared
    
    pod 'SwiftyTimer'
end

target 'NumPad' do
    use_frameworks! # :linkage => :static
    
    shared
    
    pod 'FirebasePerformance'
    pod 'SwiftRater'
    pod 'RevealingSplashView', :git => 'https://github.com/PiXeL16/RevealingSplashView.git'
    pod 'TextAttributes'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "14.0"
    end
  end
end
