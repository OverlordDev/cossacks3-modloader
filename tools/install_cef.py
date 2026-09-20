# Раскладка рантайма CEF в <папка игры>/cef.
#
#   python tools/install_cef.py <распакованный cef_binary_...> "C:/.../Cossacks 3"
#
# Модлоадер грузит libcef.dll из этой папки сам (CefScopedLibraryLoader), поэтому в папке игры
# ничего кроме cef/ не появляется и без CEF модлоадер работает как раньше.
#
# Сборку взять тут (windows32, тип minimal): https://cef-builds.spotifycdn.com/index.json
import os
import shutil
import sys

# Что нужно в рантайме. libEGL/libGLESv2/swiftshader/vulkan — софтверный рендер,
# он нам и нужен: с ним CEF не трогает драйвер видеокарты.
BINARIES = [
    "libcef.dll",
    "chrome_elf.dll",
    "v8_context_snapshot.bin",
    "libEGL.dll",
    "libGLESv2.dll",
    "d3dcompiler_47.dll",
    "vk_swiftshader.dll",
    "vk_swiftshader_icd.json",
    "vulkan-1.dll",
]
RESOURCES = ["chrome_100_percent.pak", "chrome_200_percent.pak", "resources.pak", "icudtl.dat"]
LOCALES = ["en-US.pak", "ru.pak"]  # остальные 218 не нужны, это ~65 МБ


def copy(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    return os.path.getsize(dst)


def main():
    if len(sys.argv) < 3:
        sys.exit("использование: install_cef.py <папка SDK> <папка игры>")
    sys.stdout.reconfigure(encoding="utf-8")
    sdk, game = sys.argv[1], sys.argv[2]
    out = os.path.join(game, "cef")

    total = 0
    missing = []
    for name in BINARIES:
        s = os.path.join(sdk, "Release", name)
        if os.path.exists(s):
            total += copy(s, os.path.join(out, name))
        else:
            missing.append(name)
    for name in RESOURCES:
        s = os.path.join(sdk, "Resources", name)
        if os.path.exists(s):
            total += copy(s, os.path.join(out, name))
        else:
            missing.append(name)
    for name in LOCALES:
        s = os.path.join(sdk, "Resources", "locales", name)
        if os.path.exists(s):
            total += copy(s, os.path.join(out, "locales", name))
        else:
            missing.append("locales/" + name)

    print("%s: %.0f МБ" % (out, total / 1048576))
    if missing:
        print("не найдено в SDK:", ", ".join(missing))


if __name__ == "__main__":
    main()
