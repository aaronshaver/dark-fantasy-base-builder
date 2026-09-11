#!/usr/bin/env python3
"""Reproduce the checked-in, dependency-free Xcode project using Python's standard library."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'DarkFortress.xcodeproj'
objects = {}


class Ref(str):
    pass


def identity(name):
    return Ref(hashlib.sha1(name.encode()).hexdigest()[:24].upper())


def add(key_name, isa, **values):
    key = identity(key_name)
    objects[key] = {'isa': Ref(isa), **values}
    return key


def encode(value, level=0):
    indent = '\t' * level
    if isinstance(value, Ref):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        return '(\n' + ''.join(f'{indent}\t{encode(item, level + 1)},\n' for item in value) + indent + ')'
    return '{\n' + ''.join(f'{indent}\t{encode(key)} = {encode(item, level + 1)};\n' for key, item in value.items()) + indent + '}'


def file(path, kind='sourcecode.swift'):
    return add('file:' + path, 'PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='SOURCE_ROOT')


core = [file(str(path.relative_to(ROOT))) for path in sorted((ROOT / 'Sources/FortressCore').glob('*.swift'))]
app = [file(str(path.relative_to(ROOT))) for path in sorted((ROOT / 'DarkFortress/App').glob('*.swift'))]
development = [file(str(path.relative_to(ROOT))) for path in sorted((ROOT / 'DarkFortress/Development').glob('*.swift'))]
presentation = [file(str(path.relative_to(ROOT))) for path in sorted((ROOT / 'DarkFortress/Presentation').glob('*.swift'))]
unit = [file('Tests/FortressCoreTests/FortressCoreTests.swift')]
ui = [file('DarkFortressUITests/GameUITests.swift')]
resources = [file('DarkFortress/Resources/Pixel.atlas', 'folder.skatlas'),
             file('DarkFortress/Resources/Assets.xcassets', 'folder.assetcatalog'),
             file('DarkFortress/Resources/palette.json', 'text.json')]


def group(name, children):
    return add('group:' + name, 'PBXGroup', children=children, name=name, sourceTree='<group>')


art_package = add('package:art', 'XCLocalSwiftPackageReference', relativePath='.')
art_product = add('package-product:art', 'XCSwiftPackageProductDependency', package=art_package, productName='FortressArt')
art_link = add('package-link:art', 'PBXBuildFile', productRef=art_product)

products = []
targets = []
target_ids = [identity('target:' + name) for name in ['DarkFortress', 'FortressCoreTests', 'DarkFortressUITests']]


def configs(name, base):
    items = []
    for mode in ['Debug', 'Release']:
        settings = dict(base)
        if name == 'project':
            settings.update(SWIFT_OPTIMIZATION_LEVEL='-Onone' if mode == 'Debug' else '-O',
                            DEBUG_INFORMATION_FORMAT='dwarf' if mode == 'Debug' else 'dwarf-with-dsym',
                            ENABLE_TESTABILITY='YES' if mode == 'Debug' else 'NO',
                            SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG $(inherited)' if mode == 'Debug' else '$(inherited)',
                            ONLY_ACTIVE_ARCH='YES' if mode == 'Debug' else 'NO')
        items.append(add(f'config:{name}:{mode}', 'XCBuildConfiguration', buildSettings=settings, name=mode))
    return add('configs:' + name, 'XCConfigurationList', buildConfigurations=items, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')


project_config = configs('project', {
    'SDKROOT': 'iphoneos', 'IPHONEOS_DEPLOYMENT_TARGET': '16.0', 'SWIFT_VERSION': '5.0',
    'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES', 'CLANG_WARN_DOCUMENTATION_COMMENTS': 'YES',
    'GCC_WARN_UNDECLARED_SELECTOR': 'YES', 'GCC_WARN_UNUSED_FUNCTION': 'YES', 'GCC_WARN_UNUSED_VARIABLE': 'YES',
    'ENABLE_STRICT_OBJC_MSGSEND': 'YES', 'ENABLE_USER_SCRIPT_SANDBOXING': 'YES',
    'TARGETED_DEVICE_FAMILY': '1', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator',
    'SUPPORTS_MACCATALYST': 'NO', 'SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD': 'NO'
})


for name, sources, extension, product_type in [
    ('DarkFortress', core + app + presentation + development, 'app', 'application'),
    ('FortressCoreTests', core + unit, 'xctest', 'bundle.unit-test'),
    ('DarkFortressUITests', ui, 'xctest', 'bundle.ui-testing')
]:
    product = add('product:' + name, 'PBXFileReference', explicitFileType='wrapper.application' if extension == 'app' else 'wrapper.cfbundle',
                  includeInIndex=0, path=f'{name}.{extension}', sourceTree='BUILT_PRODUCTS_DIR')
    products.append(product)
    source_builds = [add(f'build:{name}:{ref}', 'PBXBuildFile', fileRef=ref) for ref in sources]
    resource_builds = [add(f'resource:{name}:{ref}', 'PBXBuildFile', fileRef=ref) for ref in resources] if extension == 'app' else []
    phases = [add('sources:' + name, 'PBXSourcesBuildPhase', buildActionMask=2147483647, files=source_builds, runOnlyForDeploymentPostprocessing=0),
              add('frameworks:' + name, 'PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[art_link] if extension == 'app' else [], runOnlyForDeploymentPostprocessing=0),
              add('resources:' + name, 'PBXResourcesBuildPhase', buildActionMask=2147483647, files=resource_builds, runOnlyForDeploymentPostprocessing=0)]
    settings = {'PRODUCT_NAME': '$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.aaronshaver.darkfortress' + ('.' + name if extension != 'app' else ''),
                'CODE_SIGN_STYLE': 'Automatic', 'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@executable_path/Frameworks']}
    dependencies = []
    if extension == 'app':
        settings.update(INFOPLIST_FILE='DarkFortress/Info.plist', ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon',
                        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME='', GENERATE_INFOPLIST_FILE='NO',
                        MARKETING_VERSION='0.1.0', CURRENT_PROJECT_VERSION='1')
    else:
        settings.update(GENERATE_INFOPLIST_FILE='YES')
        proxy = add('proxy:' + name, 'PBXContainerItemProxy', containerPortal=identity('project'), proxyType=1,
                    remoteGlobalIDString=target_ids[0], remoteInfo='DarkFortress')
        dependencies = [add('dependency:' + name, 'PBXTargetDependency', target=target_ids[0], targetProxy=proxy)]
        if name == 'FortressCoreTests':
            settings.update(TEST_HOST='$(BUILT_PRODUCTS_DIR)/DarkFortress.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/DarkFortress', BUNDLE_LOADER='$(TEST_HOST)')
        else:
            settings.update(TEST_TARGET_NAME='DarkFortress')
    targets.append(add('target:' + name, 'PBXNativeTarget', buildConfigurationList=configs(name, settings), buildPhases=phases,
                       buildRules=[], dependencies=dependencies, name=name, productName=name, productReference=product,
                       productType='com.apple.product-type.' + product_type,
                       packageProductDependencies=[art_product] if extension == 'app' else []))

main = group('Dark Fortress', [group('App', app), group('Presentation', presentation), group('Development', development), group('Fortress Core', core),
                             group('Resources', resources + [file('DarkFortress/Info.plist', 'text.plist.xml')]),
                             group('Tests', unit + ui), group('Principles', [file('project_principles.md', 'net.daringfireball.markdown'),
                                                                         file('game_principles.md', 'net.daringfireball.markdown')]),
                             group('Products', products)])
project_id = add('project', 'PBXProject', attributes={'BuildIndependentTargetsInParallel': 'YES', 'LastUpgradeCheck': '2600',
    'TargetAttributes': {target_ids[0]: {'CreatedOnToolsVersion': '26.0'}, target_ids[1]: {'CreatedOnToolsVersion': '26.0', 'TestTargetID': target_ids[0]},
                         target_ids[2]: {'CreatedOnToolsVersion': '26.0', 'TestTargetID': target_ids[0]}}},
    buildConfigurationList=project_config, compatibilityVersion='Xcode 14.0', developmentRegion='en', hasScannedForEncodings=0,
    knownRegions=['en', 'Base'], packageReferences=[art_package], mainGroup=main, productRefGroup=identity('group:Products'), projectDirPath='', projectRoot='', targets=targets)
PROJECT.mkdir(exist_ok=True)
(PROJECT / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + encode({'archiveVersion': 1, 'classes': {}, 'objectVersion': 56,
                                                               'objects': objects, 'rootObject': project_id}) + '\n')


def reference(name):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{identity("target:" + name)}" BuildableName="{name}.{"app" if name == "DarkFortress" else "xctest"}" BlueprintName="{name}" ReferencedContainer="container:DarkFortress.xcodeproj"/>'


scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference('DarkFortress')}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
    <Testables>
      <TestableReference skipped="NO" parallelizable="NO">{reference('FortressCoreTests')}</TestableReference>
      <TestableReference skipped="NO" parallelizable="NO">{reference('DarkFortressUITests')}</TestableReference>
    </Testables>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">{reference('DarkFortress')}</BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference('DarkFortress')}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
scheme_path = PROJECT / 'xcshareddata/xcschemes/DarkFortress.xcscheme'
scheme_path.parent.mkdir(parents=True, exist_ok=True)
scheme_path.write_text(scheme)
print(f'Generated {PROJECT.name} with app, logic tests, and UI tests.')
