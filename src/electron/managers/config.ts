import { app } from "electron";
import fs from "fs";
import path from "path";
import os from "os";
import { Config, defaultConfig } from "../../shared/types";

const configPath = path.join(app.getPath("userData"), "settings.json");

// System-wide config paths (Nix-managed)
const systemConfigPath = "/etc/geforce-infinity/settings.json";
const userConfigPath = path.join(os.homedir(), ".config/geforce-infinity/settings.json");

let currentConfig: Config = defaultConfig;

export function loadConfig(): void {
    try {
        // Priority: app data (user local) > XDG config (Home Manager) > system config (NixOS) > defaults
        const configPaths = [configPath, userConfigPath, systemConfigPath];
        
        for (const configPathToCheck of configPaths) {
            if (fs.existsSync(configPathToCheck)) {
                currentConfig = JSON.parse(
                    fs.readFileSync(configPathToCheck, "utf-8")
                ) as Config;
                console.log(`Loaded config from: ${configPathToCheck}`);
                return;
            }
        }
        
        // No config file found, save default config
        saveConfig();
    } catch (error) {
        console.error("Error loading config:", error);
    }
}

export function saveConfig(updates: Partial<Config> = {}): void {
    try {
        currentConfig = { ...currentConfig, ...updates };
        fs.writeFileSync(configPath, JSON.stringify(currentConfig, null, 2));
    } catch (error) {
        console.error("Error saving config:", error);
    }
}

export function getConfig(): Config {
    return currentConfig;
}
