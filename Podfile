# Uncomment the next line to define a global platform for your project
#plugin 'cocoapods-binary'

#enable_bitcode_for_prebuilt_frameworks!
#keep_source_code_for_prebuilt_frameworks!
#all_binary!

def shared
    pod 'Firebase/Analytics'
    pod 'Firebase/Crashlytics'
#    pod 'Firebase/Performance'
    pod 'DynamicColor'
    pod 'TinyConstraints'
end

target 'Keyboard' do
    use_frameworks!
    
    shared
    
    pod 'SwiftyTimer'
end

target 'NumPad' do
    use_frameworks!
  
    shared
    
    pod 'SwiftRater'
    pod 'RevealingSplashView', :git => 'https://github.com/PiXeL16/RevealingSplashView.git'
    pod 'TextAttributes'
end
