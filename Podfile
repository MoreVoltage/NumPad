# Podfile

platform :ios, '8.0'

use_frameworks!

def fabric_pods
    pod 'Fabric', '~> 1.6'
    pod 'Crashlytics', '~> 3.5'
end

def ui_pods
    pod 'NumPad', '~> 0.0'
end

target :NumPadApp do
    fabric_pods
end

target :Keyboard do
    ui_pods
end
