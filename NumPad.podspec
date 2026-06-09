Pod::Spec.new do |s|
  s.name = 'NumPad'
  s.version = '1.7.0'
  s.summary = 'Shared core model and preference code for the NumPad iOS keyboard.'
  s.description = <<-DESC
    NumPad is an iOS numeric keyboard and companion app. This pod exposes the
    shared core model and preference code used by the app and keyboard targets.
  DESC
  s.homepage = 'https://github.com/MoreVoltage/NumPad'
  s.license = { :type => 'MIT' }
  s.author = { 'More Voltage' => 'support@morevoltage.com' }
  s.source = { :git => 'https://github.com/MoreVoltage/NumPad.git', :tag => s.version.to_s }

  s.platform = :ios, '14.0'
  s.swift_version = '5.0'
  s.static_framework = true

  s.source_files = [
    'NumPad/Libraries/SharedExtensions.swift',
    'NumPad/Libraries/Keyboard.swift'
  ]
end
