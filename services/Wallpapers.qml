pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Nilastia.Config
import Nilastia.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: GlobalConfig.services.smartScheme ? [] : ["--no-smart"]
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property bool previewColourLock
    property bool pendingPreviewClear

    function isParallaxPath(p: string): bool {
        if (!p) return false;
        let lower = p.toLowerCase();
        return lower.endsWith("wallpaper.json") || lower.endsWith(".nilawall") || lower.endsWith(".json");
    }

    property string parallaxPreviewPath: ""
    readonly property string currentPreviewPath: {
        let path = root.current;
        if (!path) return "";
        if (root.isParallaxPath(path)) {
            return root.parallaxPreviewPath;
        }
        return path;
    }

    function getCategoryFor(w: FileSystemEntry): string {
        let category = w.parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category;
    }

    function setRandom(): void {
        Quickshell.execDetached(["nilastia", "wallpaper", "-r", ...smartArg]);
    }

    function setWallpaper(path: string): void {
        actualCurrent = path;
        Quickshell.execDetached(["nilastia", "wallpaper", "-f", path, ...smartArg]);
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;

        if (Colours.scheme === "dynamic")
            getPreviewColoursProc.running = true;
    }

    function stopPreview(): void {
        showPreview = false;
        if (previewColourLock)
            pendingPreviewClear = true;
        else
            Colours.showPreview = false;
    }

    onPreviewColourLockChanged: {
        if (!previewColourLock && pendingPreviewClear)
            Colours.showPreview = false;
    }

    list: wallpapers.entries
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        target: "wallpaper"
    }

    property bool isInitializingFallback: false

    FileView {
        path: root.currentNamePath
        watchChanges: true
        printErrors: false

        onLoaded: {
            let p = text().trim();
            if (p) {
                root.actualCurrent = p;
                root.isInitializingFallback = false;
            } else if (!root.isInitializingFallback) {
                root.isInitializingFallback = true;
                root.actualCurrent = root.fallback;
            }
        }
        onLoadFailed: {
            if (!root.isInitializingFallback) {
                root.isInitializingFallback = true;
                root.actualCurrent = root.fallback;
            }
        }
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Images
    }

    Process {
        id: getPreviewColoursProc

        command: ["nilastia", "wallpaper", "-p", root.previewPath, ...root.smartArg]
        stdout: StdioCollector {
            onStreamFinished: {
                Colours.load(text, true);
                Colours.showPreview = true;
            }
        }
    }

    FileView {
        id: activeWallpaperReader
        path: root.isParallaxPath(root.current) ? root.current : ""
        printErrors: false
        watchChanges: true
        onFileChanged: reload()

        onLoaded: {
            try {
                let json = JSON.parse(text());
                let layers = json.parallax?.layers || [];
                let firstImgSrc = "";
                for (let i = 0; i < layers.length; i++) {
                    let src = layers[i].source || "";
                    if (src && !src.startsWith("virtual://")) {
                        firstImgSrc = src;
                        break;
                    }
                }
                if (firstImgSrc) {
                    if (firstImgSrc.startsWith("data:")) {
                        root.parallaxPreviewPath = firstImgSrc;
                    } else {
                        let idx = root.current.lastIndexOf("/");
                        let basePath = idx >= 0 ? root.current.slice(0, idx + 1) : "";
                        root.parallaxPreviewPath = basePath + firstImgSrc;
                    }
                } else {
                    root.parallaxPreviewPath = "";
                }
            } catch(e) {
                root.parallaxPreviewPath = "";
            }
        }
        onLoadFailed: {
            root.parallaxPreviewPath = "";
        }
    }
}
