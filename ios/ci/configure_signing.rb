# frozen_string_literal: true

# Switches the Runner target's Release configuration to manual App Store
# signing, for CI only (frontend/.github/workflows/build-ios.yml). The change
# is made on the runner's checkout and never committed: the checked-in
# project keeps Xcode's automatic signing for anyone building on a Mac.
#
#   IOS_TEAM_ID=ABCDE12345 IOS_BUNDLE_ID=com.example.app \
#   IOS_PROFILE_UUID=<uuid> ruby ios/ci/configure_signing.rb [Runner.xcodeproj]
#
# Fails closed: a missing or malformed value, a missing Runner target or a
# missing Release configuration stops the build instead of falling back to
# automatic signing.
require 'xcodeproj'

def fetch(name, pattern)
  value = ENV.fetch(name, '')
  abort "configure_signing: #{name} is missing or malformed" unless value.match?(pattern)
  value
end

team = fetch('IOS_TEAM_ID', /\A[A-Z0-9]{10}\z/)
bundle = fetch('IOS_BUNDLE_ID', /\A[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+\z/)
profile = fetch('IOS_PROFILE_UUID', /\A[0-9A-Fa-f-]{36}\z/)

path = ARGV[0] || File.expand_path('../Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(path)
target = project.targets.find { |t| t.name == 'Runner' }
abort 'configure_signing: no Runner target' unless target
config = target.build_configurations.find { |c| c.name == 'Release' }
abort 'configure_signing: Runner has no Release configuration' unless config

settings = config.build_settings
settings['CODE_SIGN_STYLE'] = 'Manual'
settings['DEVELOPMENT_TEAM'] = team
settings['CODE_SIGN_IDENTITY'] = 'Apple Distribution'
settings['CODE_SIGN_IDENTITY[sdk=iphoneos*]'] = 'Apple Distribution'
settings['PROVISIONING_PROFILE_SPECIFIER'] = profile
settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle
project.save

puts "configure_signing: Runner/Release -> manual, team #{team}, bundle #{bundle}, profile #{profile}"
