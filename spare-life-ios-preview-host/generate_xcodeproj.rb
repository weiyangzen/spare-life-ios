#!/usr/bin/env ruby

require 'fileutils'
require 'pathname'
require 'xcodeproj'

ROOT = Pathname(__dir__).realpath
REPO_ROOT = ROOT.parent
PROJECT_PATH = ROOT.join('SpareLifePreviewHost.xcodeproj')
APP_NAME = 'SpareLifePreviewHost'
BUNDLE_ID = 'com.wangweiyang.sparelife.previewhost'
UI_TEST_NAME = 'SpareLifePreviewHostUITests'
UI_TEST_BUNDLE_ID = 'com.wangweiyang.sparelife.previewhost.uitests'
DEPLOYMENT_TARGET = '16.0'
UI_TEST_SOURCE_DIRECTORY = ROOT.join('UITests')

SOURCE_DIRECTORIES = [
  REPO_ROOT.join('spare-life-ios-app/App'),
  REPO_ROOT.join('spare-life-ios-app/Domain/Models'),
  REPO_ROOT.join('spare-life-ios-app/Features')
].freeze

RESOURCE_PATHS = [
  ROOT.join('Resources/Assets.xcassets')
].freeze

def ensure_group(parent, path_parts)
  group = parent
  path_parts.each do |part|
    existing = group.children.find { |child| child.isa == 'PBXGroup' && child.display_name == part }
    group = existing || group.new_group(part)
  end
  group
end

def add_swift_sources(project, target, container_group, root_path)
  Dir.glob(root_path.join('**/*.swift')).sort.each do |file_path|
    next if file_path.include?('/App/CLI/')

    file = Pathname(file_path)
    relative_to_project = file.relative_path_from(PROJECT_PATH.parent).to_s
    relative_dir_parts = file.relative_path_from(root_path).each_filename.to_a[0...-1]
    group = ensure_group(container_group, relative_dir_parts)
    file_ref = group.new_file(relative_to_project)
    target.add_file_references([file_ref])
  end
end

def add_resource_path(target, group, resource_path)
  file = Pathname(resource_path)
  relative_to_project = file.relative_path_from(PROJECT_PATH.parent).to_s
  file_ref = group.new_file(relative_to_project)
  target.add_resources([file_ref])
end

FileUtils.rm_rf(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH.to_s)
project.root_object.attributes['LastUpgradeCheck'] = '2600'

app_group = project.main_group.new_group(APP_NAME)
host_sources_group = app_group.new_group('App')
shared_group = app_group.new_group('SharedSources')
ui_tests_group = app_group.new_group('UITests')
resources_group = app_group.new_group('Resources')

target = project.new_target(:application, APP_NAME, :ios, DEPLOYMENT_TARGET)
target.product_name = APP_NAME

ui_test_target = project.new_target(:ui_test_bundle, UI_TEST_NAME, :ios, DEPLOYMENT_TARGET)
ui_test_target.product_name = UI_TEST_NAME
ui_test_target.add_dependency(target)

project.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
end

target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_ID
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['SUPPORTS_MACCATALYST'] = 'NO'
  config.build_settings['SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD'] = 'NO'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UIRequiresFullScreen'] = 'NO'
  config.build_settings['INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone'] =
    'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight'
  config.build_settings['INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad'] =
    'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = ''
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SDKROOT'] = 'iphoneos'
end

ui_test_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = UI_TEST_BUNDLE_ID
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = ''
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SDKROOT'] = 'iphoneos'
  config.build_settings['TEST_TARGET_NAME'] = APP_NAME
end

host_app_file = host_sources_group.new_file('App/SpareLifePreviewHostApp.swift')
target.add_file_references([host_app_file])

SOURCE_DIRECTORIES.each do |source_dir|
  subgroup = shared_group.new_group(source_dir.basename.to_s)
  add_swift_sources(project, target, subgroup, source_dir)
end

add_swift_sources(project, ui_test_target, ui_tests_group, UI_TEST_SOURCE_DIRECTORY)

RESOURCE_PATHS.each do |resource_path|
  add_resource_path(target, resources_group, resource_path)
end

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(target, ui_test_target)
scheme.test_action.add_macro_expansion(Xcodeproj::XCScheme::MacroExpansion.new(target))
scheme.set_launch_target(target)
scheme.save_as(PROJECT_PATH.to_s, APP_NAME, true)

project.save

puts "Generated #{PROJECT_PATH}"
