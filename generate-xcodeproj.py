#!/usr/bin/env python3
"""
基于 Xcode 26 模板格式生成 EyeTrainer.xcodeproj
严格遵循 objectVersion=77, classes={ }; 格式
"""
import os, hashlib

PROJ_ROOT = os.path.dirname(os.path.abspath(__file__))

def uid(seed):
    return hashlib.sha256(seed.encode()).hexdigest()[:24].upper()

# === FILES (path -> target: "main" | "xpc" | "both") ===
FILES = {
    # Main app
    "EyeTrainer/App/EyeTrainerApp.swift": "main",
    "EyeTrainer/ViewModel/AppViewModel.swift": "main",
    "EyeTrainer/Views/MenuBarView.swift": "main",
    "EyeTrainer/Views/FloatingPanel.swift": "main",
    "EyeTrainer/Views/ManualControlView.swift": "main",
    "EyeTrainer/Views/Components/BrightnessSlider.swift": "main",
    "EyeTrainer/Views/Components/CurveSelector.swift": "main",
    "EyeTrainer/Views/Settings/SettingsWindow.swift": "main",
    "EyeTrainer/Views/Settings/TrainingTab.swift": "main",
    "EyeTrainer/Views/Settings/HotkeyTab.swift": "main",
    "EyeTrainer/Views/Settings/NotificationTab.swift": "main",
    "EyeTrainer/Views/Settings/AboutTab.swift": "main",
    "EyeTrainer/Services/XPCBridge.swift": "main",
    "EyeTrainer/Services/HotkeyManager.swift": "main",
    "EyeTrainer/Resources/Info.plist": "no-compile",
    # Shared (both targets)
    "EyeTrainer/Models/TrainingSettings.swift": "both",
    "Shared/XPCProtocol.swift": "both",
    "BrightnessXPC/BrightnessController.swift": "both",
    "BrightnessXPC/CurveEngine.swift": "both",
    "BrightnessXPC/TimerDriver.swift": "both",
    # XPC only
    "BrightnessXPC/main.swift": "xpc",
    "BrightnessXPC/XPCServiceDelegate.swift": "xpc",
    "BrightnessXPC/Info.plist": "no-compile",
}

# The repository keeps the app sources one level below the top-level
# EyeTrainer directory, while this generated project lives at the root.
FILES = {
    (f"EyeTrainer/{path}" if path.startswith("EyeTrainer/") else path): target
    for path, target in FILES.items()
}

# === IDs ===
file_ids = {p: uid(f"FR-{p}") for p in FILES}
main_target_id = uid("T-main")
xpc_target_id = uid("T-xpc")
main_prod_id = uid("PROD-main")
xpc_prod_id = uid("PROD-xpc")
proj_id = uid("PROJ")
main_grp_id = uid("GRP-main")
prod_grp_id = uid("GRP-products")

# Build config lists
main_config_list = uid("CL-main")
xpc_config_list = uid("CL-xpc")
proj_config_list = uid("CL-proj")
debug_conf = uid("CONF-debug")
release_conf = uid("CONF-release")
debug_xpc = uid("CONF-debug-xpc")
release_xpc = uid("CONF-release-xpc")

# Build phases
main_src_phase = uid("BP-src-main")
xpc_src_phase = uid("BP-src-xpc")
copy_xpc_phase = uid("BP-copy-xpc")

# Group IDs
grp_ids = {}
for p in FILES:
    d = os.path.dirname(p)
    parts = d.split("/")
    for i in range(len(parts)):
        prefix = "/".join(parts[:i+1])
        if prefix not in grp_ids:
            grp_ids[prefix] = uid(f"GRP-{prefix}")

# Assign children to groups
grp_children = {g: [] for g in grp_ids.values()}
for p, target in FILES.items():
    parent = os.path.dirname(p)
    grp_children[grp_ids[parent]].append(file_ids[p])

# Link parent groups to child sub-groups
for pp, pg in grp_ids.items():
    for cp, cg in grp_ids.items():
        if cp.startswith(pp + "/") and cp.count("/") == pp.count("/") + 1:
            if cg not in grp_children[pg]:
                grp_children[pg].append(cg)

# Root group children
root_children = [
    grp_ids["EyeTrainer"],
    grp_ids["BrightnessXPC"],
    grp_ids["Shared"],
    prod_grp_id
]

# Product group children
prod_children = [main_prod_id, xpc_prod_id]

# === GENERATE ===

buf = []
def L(s=""):
    buf.append(s)

# Header
L("// !$*UTF8*$!")
L("{")
L("\tarchiveVersion = 1;")
L("\tclasses = {")
L("\t};")
L("\tobjectVersion = 77;")
L("\tobjects = {")

# === PBXBuildFile ===
L("")
L("/* Begin PBXBuildFile section */")

build_files = {}
for p, target in FILES.items():
    if target == "no-compile":
        continue
    fid = file_ids[p]
    for tname, tid in [("main", main_target_id), ("xpc", xpc_target_id)]:
        if target in (tname, "both"):
            bfid = uid(f"BF-{p}-{tname}")
            build_files[(p, tname)] = bfid
            L(f"\t\t{bfid} /* {os.path.basename(p)} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid}; }};")

# Copy XPC
copy_bfid = uid("BF-copy-xpc")
L(f"\t\t{copy_bfid} /* BrightnessXPC.xpc in Embed XPC Services */ = {{isa = PBXBuildFile; fileRef = {xpc_prod_id}; }};")

L("/* End PBXBuildFile section */")

# === PBXCopyFilesBuildPhase ===
L("")
L("/* Begin PBXCopyFilesBuildPhase section */")
L(f"\t\t{copy_xpc_phase} /* Embed XPC Services */ = {{")
L(f"\t\t\tisa = PBXCopyFilesBuildPhase;")
L(f"\t\t\tbuildActionMask = 2147483647;")
L(f'\t\t\tdstPath = "$(CONTENTS_FOLDER_PATH)/XPCServices";')
L(f"\t\t\tdstSubfolderSpec = 16;")
L(f"\t\t\tfiles = (")
L(f"\t\t\t\t{copy_bfid},")
L(f"\t\t\t);")
L(f'\t\t\tname = "Embed XPC Services";')
L(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
L(f"\t\t}};")
L("/* End PBXCopyFilesBuildPhase section */")

# === PBXFileReference ===
L("")
L("/* Begin PBXFileReference section */")
for p, target in FILES.items():
    ext = os.path.splitext(p)[1]
    ft = {".swift": "sourcecode.swift", ".plist": "text.plist.xml", ".entitlements": "text.plist.entitlements"}.get(ext, "text")
    name = os.path.basename(p)
    L(f'\t\t{file_ids[p]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ft}; path = "{name}"; sourceTree = "<group>"; }};')

# Products
L(f'\t\t{main_prod_id} /* EyeTrainer.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; path = EyeTrainer.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
L(f'\t\t{xpc_prod_id} /* BrightnessXPC.xpc */ = {{isa = PBXFileReference; explicitFileType = "wrapper.xpc-service"; path = BrightnessXPC.xpc; sourceTree = BUILT_PRODUCTS_DIR; }};')
L("/* End PBXFileReference section */")

# === PBXGroup ===
L("")
L("/* Begin PBXGroup section */")

# Main group
L(f"\t\t{main_grp_id} = {{isa = PBXGroup; children = ({', '.join(root_children)}); sourceTree = \"<group>\"; }};")

# Product group
L(f"\t\t{prod_grp_id} /* Products */ = {{isa = PBXGroup; children = ({', '.join(prod_children)}); name = Products; sourceTree = \"<group>\"; }};")

# Other groups
for pp, gid in grp_ids.items():
    children = grp_children[gid]
    name = pp.rsplit("/", 1)[-1]
    if children:
        L(f'\t\t{gid} /* {name} */ = {{isa = PBXGroup; children = ({", ".join(children)}); path = "{name}"; sourceTree = "<group>"; }};')

L("/* End PBXGroup section */")

# === PBXNativeTarget ===
L("")
L("/* Begin PBXNativeTarget section */")

def write_target(tid, tname, prod_id, src_phase_id, extra_phase_ids, ptype):
    L(f"\t\t{tid} /* {tname} */ = {{")
    L(f"\t\t\tisa = PBXNativeTarget;")
    L(f"\t\t\tbuildConfigurationList = {main_config_list if ptype == 'application' else xpc_config_list};")
    L(f"\t\t\tbuildPhases = (")
    L(f"\t\t\t\t{src_phase_id},")
    for ep in extra_phase_ids:
        L(f"\t\t\t\t{ep},")
    L(f"\t\t\t);")
    L(f"\t\t\tbuildRules = (")
    L(f"\t\t\t);")
    L(f"\t\t\tdependencies = (")
    L(f"\t\t\t);")
    L(f"\t\t\tname = {tname};")
    L(f"\t\t\tproductName = {tname};")
    L(f"\t\t\tproductReference = {prod_id};")
    L(f'\t\t\tproductType = "com.apple.product-type.{ptype}";')
    L(f"\t\t}};")

write_target(main_target_id, "EyeTrainer", main_prod_id, main_src_phase, [copy_xpc_phase], "application")
write_target(xpc_target_id, "BrightnessXPC", xpc_prod_id, xpc_src_phase, [], "xpc-service")

L("/* End PBXNativeTarget section */")

# === PBXProject ===
L("")
L("/* Begin PBXProject section */")
L(f"\t\t{proj_id} /* Project object */ = {{")
L(f"\t\t\tisa = PBXProject;")
L(f"\t\t\tattributes = {{")
L(f"\t\t\t\tBuildIndependentTargetsInParallel = 1;")
L(f"\t\t\t\tLastSwiftUpdateCheck = 2600;")
L(f"\t\t\t\tLastUpgradeCheck = 2600;")
L(f"\t\t\t}};")
L(f"\t\t\tbuildConfigurationList = {proj_config_list};")
L(f'\t\t\tcompatibilityVersion = "Xcode 14.0";')
L(f'\t\t\tdevelopmentRegion = "zh-Hans";')
L(f"\t\t\thasScannedForEncodings = 0;")
L(f"\t\t\tmainGroup = {main_grp_id};")
L(f"\t\t\tproductRefGroup = {prod_grp_id};")
L(f'\t\t\tprojectDirPath = "";')
L(f'\t\t\tprojectRoot = "";')
L(f"\t\t\ttargets = (")
L(f"\t\t\t\t{main_target_id},")
L(f"\t\t\t\t{xpc_target_id},")
L(f"\t\t\t);")
L(f"\t\t}};")
L("/* End PBXProject section */")

# === PBXSourcesBuildPhase ===
L("")
L("/* Begin PBXSourcesBuildPhase section */")

main_src_files = [bfid for (p, t), bfid in build_files.items() if t == "main"]
xpc_src_files = [bfid for (p, t), bfid in build_files.items() if t == "xpc"]

L(f"\t\t{main_src_phase} /* Sources */ = {{")
L(f"\t\t\tisa = PBXSourcesBuildPhase;")
L(f"\t\t\tbuildActionMask = 2147483647;")
L(f"\t\t\tfiles = (")
for bfid in main_src_files:
    L(f"\t\t\t\t{bfid},")
L(f"\t\t\t);")
L(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
L(f"\t\t}};")

L(f"\t\t{xpc_src_phase} /* Sources */ = {{")
L(f"\t\t\tisa = PBXSourcesBuildPhase;")
L(f"\t\t\tbuildActionMask = 2147483647;")
L(f"\t\t\tfiles = (")
for bfid in xpc_src_files:
    L(f"\t\t\t\t{bfid},")
L(f"\t\t\t);")
L(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
L(f"\t\t}};")

L("/* End PBXSourcesBuildPhase section */")

# === XCBuildConfiguration ===
L("")
L("/* Begin XCBuildConfiguration section */")

build_settings_debug = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CODE_SIGN_STYLE": "Automatic",
    "COPY_PHASE_STRIP": "NO",
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_TESTABILITY": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": '("DEBUG=1","$(inherited)",)',
    "INFOPLIST_FILE": "EyeTrainer/EyeTrainer/Resources/Info.plist",
    "LD_RUNPATH_SEARCH_PATHS": '("$(inherited)","@executable_path/../Frameworks",)',
    "MACOSX_DEPLOYMENT_TARGET": "14.0",
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "MTL_FAST_MATH": "YES",
    "ONLY_ACTIVE_ARCH": "YES",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.wenquan.eye-trainer",
    'PRODUCT_NAME': '"$(TARGET_NAME)"',
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS': '"DEBUG $(inherited)"',
    'SWIFT_OPTIMIZATION_LEVEL': '"-Onone"',
    "SWIFT_VERSION": "5.0",
}

build_settings_release = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CODE_SIGN_STYLE": "Automatic",
    "COPY_PHASE_STRIP": "NO",
    "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
    "ENABLE_NS_ASSERTIONS": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
    "GCC_OPTIMIZATION_LEVEL": "s",
    "INFOPLIST_FILE": "EyeTrainer/EyeTrainer/Resources/Info.plist",
    "LD_RUNPATH_SEARCH_PATHS": '("$(inherited)","@executable_path/../Frameworks",)',
    "MACOSX_DEPLOYMENT_TARGET": "14.0",
    "MTL_ENABLE_DEBUG_INFO": "NO",
    "MTL_FAST_MATH": "YES",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.wenquan.eye-trainer",
    'PRODUCT_NAME': '"$(TARGET_NAME)"',
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "SWIFT_VERSION": "5.0",
}

xpc_build_settings = {
    "CODE_SIGN_STYLE": "Automatic",
    "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
    "INFOPLIST_FILE": "BrightnessXPC/Info.plist",
    "MACOSX_DEPLOYMENT_TARGET": "14.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.wenquan.BrightnessXPC",
    'PRODUCT_NAME': '"$(TARGET_NAME)"',
    "SWIFT_VERSION": "5.0",
    "SKIP_INSTALL": "YES",
}

def write_config(cid, name, settings):
    L(f"\t\t{cid} /* {name} */ = {{")
    L(f"\t\t\tisa = XCBuildConfiguration;")
    L(f"\t\t\tbuildSettings = {{")
    for key, val in settings.items():
        L(f"\t\t\t\t{key} = {val};")
    L(f"\t\t\t}};")
    L(f'\t\t\tname = {name};')
    L(f"\t\t}};")

write_config(debug_conf, "Debug", build_settings_debug)
write_config(release_conf, "Release", build_settings_release)
write_config(debug_xpc, "Debug", xpc_build_settings)
write_config(release_xpc, "Release", xpc_build_settings)

L("/* End XCBuildConfiguration section */")

# === XCConfigurationList ===
L("")
L("/* Begin XCConfigurationList section */")

for cl_id, name, debug_id, release_id in [
    (main_config_list, "EyeTrainer", debug_conf, release_conf),
    (xpc_config_list, "BrightnessXPC", debug_xpc, release_xpc),
    (proj_config_list, "Project", debug_conf, release_conf),
]:
    L(f"\t\t{cl_id} /* Build configuration list for PBXNativeTarget \"{name}\" */ = {{")
    L(f"\t\t\tisa = XCConfigurationList;")
    L(f"\t\t\tbuildConfigurations = (")
    L(f"\t\t\t\t{debug_id},")
    L(f"\t\t\t\t{release_id},")
    L(f"\t\t\t);")
    L(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    L(f"\t\t\tdefaultConfigurationName = Release;")
    L(f"\t\t}};")

L("/* End XCConfigurationList section */")

L("\t};")
L(f"\trootObject = {proj_id} /* Project object */;")
L("}")

# === POST-PROCESS: Remove trailing commas ===
import re
result = "\n".join(buf)
result = re.sub(r',(\s*\n\s*\);)', r'\1', result)

# Write
pbxproj_dir = os.path.join(PROJ_ROOT, "EyeTrainer.xcodeproj")
os.makedirs(pbxproj_dir, exist_ok=True)
with open(os.path.join(pbxproj_dir, "project.pbxproj"), "w") as f:
    f.write(result)

print("✅ project.pbxproj generated!")

# Create workspace
ws_dir = os.path.join(pbxproj_dir, "project.xcworkspace")
os.makedirs(ws_dir, exist_ok=True)
with open(os.path.join(ws_dir, "contents.xcworkspacedata"), "w") as f:
    f.write('''<?xml version="1.0" encoding="UTF-8"?>
<Workspace version = "1.0">
   <FileRef location = "self:">
   </FileRef>
</Workspace>''')

# Create scheme
sc_dir = os.path.join(pbxproj_dir, "xcshareddata", "xcschemes")
os.makedirs(sc_dir, exist_ok=True)
with open(os.path.join(sc_dir, "EyeTrainer.xcscheme"), "w") as f:
    f.write(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "2600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES" buildArchitectures = "Automatic">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{main_target_id}" BuildableName = "EyeTrainer.app" BlueprintName = "EyeTrainer" ReferencedContainer = "container:EyeTrainer.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{main_target_id}" BuildableName = "EyeTrainer.app" BlueprintName = "EyeTrainer" ReferencedContainer = "container:EyeTrainer.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
</Scheme>''')

print("✅ Workspace & scheme created")
