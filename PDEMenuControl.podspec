#
# Be sure to run `pod lib lint PDEMenuControl.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PDEMenuControl'
  s.version          = '0.1.10'
  s.summary          = 'This library provides a horizontal menu bar. You can use it for apps that have swipe-gesture-based navigations.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
This library provides a horizontal menu bar. You can use it for apps that have swipe-gesture-based navigations. This menu bar contains a selection indicator that animates beautifully and uniquely, also return haptic feedbacks when menu bar changes its selection, that makes clarify user's control and provides intuitive experiences.
                       DESC

  s.homepage         = 'https://github.com/p0dee/PDEMenuControl'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'p0dee' => 't.takeshi.uc@gmail.com' }
  s.source           = { :git => 'https://github.com/p0dee/PDEMenuControl.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/p0dee'

  s.swift_version    = '4.2'
  s.ios.deployment_target = '10.0'

  s.source_files = 'PDEMenuControl/Classes/**/*'
  
  # s.resource_bundles = {
  #   'PDEMenuControl' => ['PDEMenuControl/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
