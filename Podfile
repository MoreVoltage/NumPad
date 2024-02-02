platform :ios, '14.0'
use_frameworks!

# Define an abstract target for shared dependencies
abstract_target 'SharedDependencies' do
    pod 'FirebaseAnalytics'
    pod 'FirebaseCrashlytics'
    pod 'GoogleUtilities'
    pod 'DynamicColor'
    pod 'TinyConstraints'
    
    target 'Keyboard' do
        pod 'SwiftyTimer'
    end
    
    target 'NumPad' do
        pod 'FirebasePerformance'
        pod 'SwiftRater'
        pod 'RevealingSplashView', :git => 'https://github.com/PiXeL16/RevealingSplashView.git'
        pod 'TextAttributes'
    end
    
    # This post_install hook applies to all the concrete targets
    post_install do |installer|
        installer.pods_project.targets.each do |target|
            target.build_configurations.each do |config|
                config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
            end
        end
    end
end
