#!/usr/bin/env ruby

require 'fileutils'
require 'pathname'
require 'xcodeproj'

ROOT = Pathname(__dir__).realpath
REPO_ROOT = ROOT.parent
PROJECT_PATH = ROOT.join('SpareLifeStage1MastersPreviewHost.xcodeproj')
APP_NAME = 'SpareLifeStage1MastersPreviewHost'
BUNDLE_ID = 'com.wangweiyang.sparelife.stage1masters.previewhost'
DEPLOYMENT_TARGET = '16.0'

HOST_SOURCE_FILES = [
  ROOT.join('App/Stage1MastersPreviewHostApp.swift'),
  ROOT.join('App/Stage1MastersPreviewRootView.swift')
].freeze

SHARED_SOURCE_FILES = [
  REPO_ROOT.join('spare-life-ios-app/App/DesignSystem/PlatformCompat.swift'),
  REPO_ROOT.join('spare-life-ios-app/App/DesignSystem/DesignTokens.swift'),
  REPO_ROOT.join('spare-life-ios-app/App/DesignSystem/WaterfallLayout.swift'),
  REPO_ROOT.join('spare-life-ios-app/Features/Shared/FeedCardProtocol.swift'),
  REPO_ROOT.join('spare-life-ios-app/Features/Shared/UnifiedWaterfallFeed.swift'),
  REPO_ROOT.join('spare-life-ios-app/Features/Masters/MasterConversationService.swift'),
  REPO_ROOT.join('spare-life-ios-app/Features/Masters/MasterLocalStateStore.swift'),
  REPO_ROOT.join('spare-life-ios-app/Features/Masters/MasterExperienceStore.swift'),
  REPO_ROOT.join('spare-life-ios-app/Features/Masters/MasterStage1Automation.swift'),
  REPO_ROOT.join('spare-life-ios-app/Features/Masters/MasterHomeView.swift')
].freeze

RESOURCE_PATHS = [
  ROOT.join('Resources/Assets.xcassets'),
  REPO_ROOT.join('assets/char'),
  REPO_ROOT.join('assets/assets'),
  REPO_ROOT.join('spare-life-ios-app/Features/Masters/Support/master_service_directory.json')
].freeze

INFO_PLIST = ROOT.join('App/Stage1MastersPreviewHostInfo.plist')

def ensure_group(parent, path_parts)
  group = parent
  path_parts.each do |part|
    existing = group.children.find { |child| child.isa == 'PBXGroup' && child.display_name == part }
    group = existing || group.new_group(part)
  end
  group
end

def add_source_file(target, root_group, file_path, base_root)
  file = Pathname(file_path)
  relative_to_project = file.relative_path_from(PROJECT_PATH.parent).to_s
  relative_parts = file.relative_path_from(base_root).each_filename.to_a
  group = ensure_group(root_group, relative_parts[0...-1])
  file_ref = group.new_file(relative_to_project)
  target.add_file_references([file_ref])
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
resources_group = app_group.new_group('Resources')

target = project.new_target(:application, APP_NAME, :ios, DEPLOYMENT_TARGET)
target.product_name = APP_NAME

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
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['INFOPLIST_FILE'] = INFO_PLIST.relative_path_from(PROJECT_PATH.parent).to_s
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = ''
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SDKROOT'] = 'iphoneos'
end

HOST_SOURCE_FILES.each do |source_file|
  add_source_file(target, host_sources_group, source_file, ROOT)
end

SHARED_SOURCE_FILES.each do |source_file|
  add_source_file(target, shared_group, source_file, REPO_ROOT)
end

RESOURCE_PATHS.each do |resource_path|
  add_resource_path(target, resources_group, resource_path)
end

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(target, nil)
scheme.set_launch_target(target)
scheme.save_as(PROJECT_PATH.to_s, APP_NAME, true)

project.save

puts "Generated #{PROJECT_PATH}"
