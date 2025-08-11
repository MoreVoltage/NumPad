platform :ios, '14.0'
use_frameworks!

# Define an abstract target for shared dependencies
abstract_target 'SharedDependencies' do
    pod 'FirebaseAnalytics'
    pod 'GoogleUtilities'
    pod 'DynamicColor'
    pod 'TinyConstraints'
    
    target 'Keyboard' do
        pod 'SwiftyTimer'
    end
    
    target 'NumPad' do
        pod 'FirebaseCrashlytics'
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
        # Avoid Xcode 16 treating some pod headers as errors
        # Pods like GoogleDataTransport use quoted includes in framework headers.
        # This forces the warning off for pods (or at least not as an error).
        config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
        # Ensure warnings are not escalated to errors for CocoaPods targets
        config.build_settings['GCC_TREAT_WARNINGS_AS_ERRORS'] = 'NO'
            end
        end
    end
end
