platform :ios, '15.0'
use_frameworks! :linkage => :static

# Define an abstract target for shared dependencies
abstract_target 'SharedDependencies' do
    pod 'DynamicColor'
    pod 'TinyConstraints'

    # Firebase is app-only: the keyboard extension never logs analytics, and statically
    # linked Firebase measurably slowed keyboard cold start (ObjC class registration at
    # dyld time) and added memory pressure against the ~50MB extension limit.
    target 'Keyboard' do
        pod 'SwiftyTimer'
    end

    target 'NumPad' do
        pod 'FirebaseAnalytics'
        pod 'GoogleUtilities'
        pod 'FirebaseCrashlytics'
        pod 'FirebasePerformance'
        pod 'SwiftRater'
        pod 'RevealingSplashView', :git => 'https://github.com/PiXeL16/RevealingSplashView.git'
        pod 'TextAttributes'

        # Unit tests @testable import NumPad; inherit search paths so they can resolve the
        # app target's pod modules (the symbols come from the host app at runtime).
        target 'NumPadTests' do
            inherit! :search_paths
        end
    end
    
    # This post_install hook applies to all the concrete targets
    post_install do |installer|
        installer.pods_project.targets.each do |target|
            target.build_configurations.each do |config|
                config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
                # Avoid Xcode 16 treating some pod headers as errors.
                # Pods like GoogleDataTransport use quoted includes in framework headers.
                config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
                # Ensure warnings are not escalated to errors for CocoaPods targets.
                config.build_settings['GCC_TREAT_WARNINGS_AS_ERRORS'] = 'NO'
            end

            # SwiftRater's podspec classifies PrivacyInfo.xcprivacy as source, which makes Xcode
            # try to compile it. The file is still packaged via the resource bundle target.
            if target.name == 'SwiftRater'
                target.source_build_phase.files.each do |build_file|
                    file_ref = build_file.file_ref
                    next unless file_ref&.path&.end_with?('PrivacyInfo.xcprivacy')

                    target.source_build_phase.remove_build_file(build_file)
                end
            end
        end
    end
end
