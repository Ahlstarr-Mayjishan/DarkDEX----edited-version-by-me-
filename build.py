import os

def lua_long_string(value):
    level = 0
    while "]" + ("=" * level) + "]" in value:
        level += 1
    eq = "=" * level
    return f"[{eq}[\n{value}\n]{eq}]"

def build():
    print("Building DEX++_compiled.luau...")
    
    # Read the hollow shell
    shell_path = "DEX++.luau"
    if not os.path.exists(shell_path):
        print(f"Error: Hollow shell '{shell_path}' not found!")
        return

    with open(shell_path, "r", encoding="utf-8") as f:
        template = f.read()

    # Load module files and format them for insertion.
    # Runtime module names stay flat for Apps.<Name>, while source files are
    # grouped by ownership so the repo is easier to navigate.
    module_groups = {
        "Core": [
            "Theme", "Lib", "Console", "SettingsWindow", "ControlCenter",
            "TaskRouter", "ThreadManager",
        ],
        "Explorer": [
            "Explorer", "EditMenu", "NavigationMenu", "ObjectMenu", "ScriptMenu", "InteractionMenu", "PlayerMenu", "NilInstanceMenu", "Properties", "SaveInstance", "ObjectLinks", "InstanceSerializer",
            "Clipboard", "Duplicate", "Deletion", "PropertyCopier", "Rename",
        ],
        "Roblox Assets Viewer": [
            "ModelViewer", "ImageViewer", "SoundViewer", "AnimationViewer",
        ],
        "Search": [
            "SmartDecompiler", "Notepad", "ClientIndex", "CodeSearch",
            "SmartSearch", "DependencyGraph", "ScriptRelations",
            "SecurityAuditor",
        ],
        "Runtime": [
            "RuntimeInspector", "RemoteUsageMap", "ActivityMap",
            "PropertyTracker", "RemoteFuzzer", "ClientIntelligence",
            "InspectorHub",
        ],
        "Tools": [
            "IDESync",
        ],
    }
    module_list = [name for names in module_groups.values() for name in names]
    module_paths = {}
    for group, names in module_groups.items():
        for name in names:
            if name.endswith("Menu"):
                module_paths[name] = os.path.join("Modules", group, "ContextMenu", f"{name}.luau")
            elif group == "Roblox Assets Viewer":
                module_paths[name] = os.path.join("Modules", "Explorer", "ContextMenu", "Roblox Assets Viewer", f"{name}.luau")
            else:
                module_paths[name] = os.path.join("Modules", group, f"{name}.luau")
    
    embedded_str = ""
    for name in module_list:
        filepath = module_paths.get(name, os.path.join("Modules", f"{name}.luau"))
        if not os.path.exists(filepath):
            filepath = filepath[:-5] + ".lua" if filepath.endswith(".luau") else os.path.join("Modules", f"{name}.lua")
            
        with open(filepath, "r", encoding="utf-8") as mf:
            m_code = mf.read().strip()
        
        # Indent the module code for clean formatting inside EmbeddedModules
        indented_code = "\n".join("    " + line for line in m_code.splitlines())
        embedded_str += f'["{name}"] = function()\n{indented_code}\nend,\n'

    plugin_entries = []
    plugin_dir = "Plugins"
    if os.path.isdir(plugin_dir):
        for filename in sorted(os.listdir(plugin_dir)):
            if not (filename.endswith(".luau") or filename.endswith(".lua")):
                continue
            plugin_path = os.path.join(plugin_dir, filename)
            with open(plugin_path, "r", encoding="utf-8") as pf:
                plugin_code = pf.read().strip()
            out_name = os.path.splitext(filename)[0] + ".lua"
            plugin_entries.append(f'["{out_name}"] = {lua_long_string(plugin_code)},')

    # Replace placeholders
    compiled = template.replace("-- [[EMBEDDED_MODULES_PLACEHOLDER]]", embedded_str.strip())
    compiled = compiled.replace("-- [[PLUGIN_SOURCES_PLACEHOLDER]]", "\n\t".join(plugin_entries))

    with open("DEX++_compiled.luau", "w", encoding="utf-8") as out:
        out.write(compiled)
    print("Built DEX++_compiled.luau successfully!")

if __name__ == "__main__":
    build()
